public import Domain
public import Foundation
public import SwiftData

public enum CourierStorage {
    @concurrent public static func makeStore(
        isStoredInMemoryOnly: Bool,
        timeSource: any TimeSource = SystemTimeSource()
    ) async throws(RepositoryError) -> LocalStore {
        let container = try makeContainer(isStoredInMemoryOnly: isStoredInMemoryOnly)
        return LocalStore(modelContainer: container, timeSource: timeSource)
    }

    @concurrent public static func makeStore(
        storeURL: URL,
        timeSource: any TimeSource = SystemTimeSource()
    ) async throws(RepositoryError) -> LocalStore {
        let container = try makeContainer(storeURL: storeURL)
        return LocalStore(modelContainer: container, timeSource: timeSource)
    }

    public static func makeContainer(isStoredInMemoryOnly: Bool) throws(RepositoryError) -> ModelContainer {
        let schema = Schema(versionedSchema: CourierSchemaV1.self)
        let configuration =
            isStoredInMemoryOnly
            ? ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration("CourierStore", schema: schema)
        return try makeContainer(schema: schema, configuration: configuration)
    }

    public static func makeContainer(storeURL: URL) throws(RepositoryError) -> ModelContainer {
        let schema = Schema(versionedSchema: CourierSchemaV1.self)
        return try makeContainer(schema: schema, configuration: ModelConfiguration(schema: schema, url: storeURL))
    }

    private static func makeContainer(
        schema: Schema,
        configuration: ModelConfiguration
    ) throws(RepositoryError) -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            throw .storageFailure(String(describing: error))
        }
    }
}
