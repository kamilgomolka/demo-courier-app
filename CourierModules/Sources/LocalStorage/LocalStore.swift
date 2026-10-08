public import Domain
import Foundation
public import SwiftData
import os

public actor LocalStore: ModelActor {
    public nonisolated let modelContainer: ModelContainer
    public nonisolated let modelExecutor: any ModelExecutor
    let timeSource: any TimeSource
    var observers: [UUID: (isolated LocalStore) -> Bool] = [:]

    public init(modelContainer: ModelContainer, timeSource: any TimeSource = SystemTimeSource()) {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.timeSource = timeSource
    }

    var activeObserverCount: Int {
        observers.count
    }

    func transact(_ mutation: () throws(RepositoryError) -> Void) throws(RepositoryError) {
        do {
            try mutation()
        } catch {
            modelContext.rollback()
            throw error
        }
        try saveAndPublish()
    }

    func saveAndPublish() throws(RepositoryError) {
        if modelContext.hasChanges {
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                Log.storage.error("Save failed: \(String(describing: error), privacy: .public)")
                throw .storageFailure(String(describing: error))
            }
        }
        for (observerID, refresh) in observers where !refresh(self) {
            observers.removeValue(forKey: observerID)
        }
    }

    func fetch<Record: PersistentModel>(_ type: Record.Type) throws(RepositoryError) -> [Record] {
        do {
            return try modelContext.fetch(FetchDescriptor<Record>())
        } catch {
            throw .storageFailure(String(describing: error))
        }
    }
}

extension LocalStore {
    nonisolated func observe<Value: Equatable & Sendable>(
        _ query: @escaping @Sendable (isolated LocalStore) throws(RepositoryError) -> Value
    ) -> AsyncStream<Value> {
        let (stream, continuation) = AsyncStream.makeStream(of: Value.self, bufferingPolicy: .bufferingNewest(1))
        let observerID = UUID()
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(observerID) }
        }
        Task { await self.addObserver(observerID, continuation: continuation, query: query) }
        return stream
    }

    private func addObserver<Value: Equatable & Sendable>(
        _ observerID: UUID,
        continuation: AsyncStream<Value>.Continuation,
        query: @escaping @Sendable (isolated LocalStore) throws(RepositoryError) -> Value
    ) {
        var lastEmitted: Value?
        let refresh: (isolated LocalStore) -> Bool = { store in
            do {
                let value = try query(store)
                guard value != lastEmitted else { return true }
                lastEmitted = value
                if case .terminated = continuation.yield(value) {
                    return false
                }
            } catch {
                Log.storage.error("Observation query failed: \(String(describing: error), privacy: .public)")
            }
            return true
        }
        guard refresh(self) else { return }
        observers[observerID] = refresh
    }

    private func removeObserver(_ observerID: UUID) {
        observers.removeValue(forKey: observerID)
    }
}
