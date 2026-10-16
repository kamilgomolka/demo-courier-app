public import Domain
import Foundation
import os

public actor SyncActor: SyncControlling {
    private enum SendResolution {
        case sent
        case serverWon(RemoteSnapshot)
    }

    private struct JobFingerprint: Hashable {
        let id: UUID
        let kind: SyncJobKind
        let notBefore: Date

        init(_ job: SyncJob) {
            id = job.id
            kind = job.kind
            notBefore = job.notBefore
        }
    }

    private let jobRepository: any SyncJobRepository
    private let localDataResetter: any LocalDataResetting
    private let api: any CourierAPI
    private let sessionRefresher: any SessionRefreshing
    private let timeSource: any TimeSource

    private var observationTask: Task<Void, Never>?
    private var wakeTask: Task<Void, Never>?
    private var wakeGeneration = 0
    private var drainTask: Task<Void, Never>?
    private var initialLoadTask: Task<Result<Void, SyncError>, Never>?
    private var resetTask: Task<RepositoryError?, Never>?
    private var isRerunRequested = false
    private var isRetryOfFailedJobsRequested = false
    private var latestJobs: [SyncJob] = []
    private var lastFingerprint: Set<JobFingerprint>?

    public init(
        jobRepository: any SyncJobRepository,
        localDataResetter: any LocalDataResetting,
        api: any CourierAPI,
        sessionRefresher: any SessionRefreshing,
        timeSource: any TimeSource = SystemTimeSource()
    ) {
        self.jobRepository = jobRepository
        self.localDataResetter = localDataResetter
        self.api = api
        self.sessionRefresher = sessionRefresher
        self.timeSource = timeSource
    }

    public func start() {
        guard observationTask == nil else { return }
        let jobs = jobRepository.observeJobs()
        observationTask = Task { [weak self] in
            for await snapshot in jobs {
                guard let self else { return }
                await self.handle(snapshot)
            }
        }
    }

    public func requestSync(_ trigger: SyncTrigger) async {
        Log.sync.info("Sync requested: \(String(describing: trigger), privacy: .public)")
        if let resetTask {
            _ = await resetTask.value
        }
        await startDrain(retryingFailedJobs: true).value
    }

    public func loadInitialData() async throws(SyncError) {
        if let resetTask {
            _ = await resetTask.value
        }
        try await runInitialLoad()
    }

    public func resetLocalData() async throws(RepositoryError) {
        let task: Task<RepositoryError?, Never>
        if let resetTask {
            task = resetTask
        } else {
            task = Task { await self.performReset() }
            resetTask = task
        }
        let failure = await task.value
        if resetTask == task {
            resetTask = nil
        }
        if let failure {
            throw failure
        }
    }

    public func stop() async {
        observationTask?.cancel()
        wakeTask?.cancel()
        drainTask?.cancel()
        initialLoadTask?.cancel()
        await observationTask?.value
        await wakeTask?.value
        await drainTask?.value
        _ = await initialLoadTask?.result
        observationTask = nil
        wakeTask = nil
        drainTask = nil
        initialLoadTask = nil
    }

    // MARK: Scheduling

    private func handle(_ jobs: [SyncJob]) {
        latestJobs = jobs
        let fingerprint = Set(jobs.map(JobFingerprint.init))
        guard fingerprint != lastFingerprint else { return }
        lastFingerprint = fingerprint
        scheduleWake()
        let now = timeSource.now()
        if jobs.contains(where: { $0.notBefore <= now && $0.attemptCount == 0 }) {
            startDrain()
        }
    }

    private func scheduleWake() {
        wakeTask?.cancel()
        wakeTask = nil
        wakeGeneration += 1
        let generation = wakeGeneration
        let now = timeSource.now()
        guard let nextDeadline = latestJobs.map(\.notBefore).filter({ $0 > now }).min() else { return }
        wakeTask = Task { [weak self, timeSource] in
            do {
                try await timeSource.sleep(until: nextDeadline)
            } catch {
                return
            }
            await self?.wakeFired(generation: generation)
        }
    }

    private func wakeFired(generation: Int) {
        guard generation == wakeGeneration else { return }
        wakeTask = nil
        startDrain()
        scheduleWake()
    }

    // MARK: Draining

    @discardableResult
    private func startDrain(retryingFailedJobs: Bool = false) -> Task<Void, Never> {
        if retryingFailedJobs {
            isRetryOfFailedJobsRequested = true
        }
        if let drainTask {
            isRerunRequested = true
            return drainTask
        }
        let task = Task { await self.runDrainCycles() }
        drainTask = task
        return task
    }

    private func runDrainCycles() async {
        repeat {
            isRerunRequested = false
            let retriesFailedJobs = isRetryOfFailedJobsRequested
            isRetryOfFailedJobsRequested = false
            await drainOnce(retryingFailedJobs: retriesFailedJobs)
        } while isRerunRequested && !Task.isCancelled
        drainTask = nil
    }

    private func drainOnce(retryingFailedJobs: Bool) async {
        var attemptedJobIDs: Set<UUID> = []
        var blockedTaskIDs: Set<TaskID> = []
        while !Task.isCancelled {
            let job: SyncJob
            do {
                let jobs = try await jobRepository.eligibleJobs(at: timeSource.now())
                guard let nextJob = jobs.first(where: { !attemptedJobIDs.contains($0.id) }) else { return }
                job = nextJob
            } catch {
                Log.sync.error("Failed to read outbox: \(String(describing: error), privacy: .public)")
                return
            }
            guard !Task.isCancelled else { return }
            attemptedJobIDs.insert(job.id)
            let taskID = job.kind.taskID
            if let taskID, blockedTaskIDs.contains(taskID) { continue }
            if job.attemptCount > 0 && !retryingFailedJobs {
                if let taskID { blockedTaskIDs.insert(taskID) }
                continue
            }
            let resolution: SendResolution
            do {
                resolution = try await sendResolvingRecoverableFailures(job)
            } catch {
                await handleSendFailure(error, for: job)
                if error == .offline || error == .cancelled { return }
                if let taskID { blockedTaskIDs.insert(taskID) }
                continue
            }
            do {
                switch resolution {
                case .sent:
                    try await jobRepository.markSynced(jobID: job.id)
                case .serverWon(let snapshot):
                    try await jobRepository.resolveConflict(jobID: job.id, serverSnapshot: snapshot)
                }
                Log.sync.info("Job \(job.id, privacy: .public) synced")
            } catch {
                Log.sync.error(
                    "Failed to acknowledge job \(job.id, privacy: .public): \(String(describing: error), privacy: .public)"
                )
                do {
                    try await jobRepository.recordFailure(jobID: job.id, failure: String(describing: error))
                } catch {
                    Log.sync.error("Failed to record failure: \(String(describing: error), privacy: .public)")
                }
                return
            }
        }
    }

    private func sendResolvingRecoverableFailures(_ job: SyncJob) async throws(SyncError) -> SendResolution {
        do {
            try await api.send(job)
            return .sent
        } catch .unauthorized {
            Log.sync.info("Job \(job.id, privacy: .public) unauthorized: refreshing session")
            try await sessionRefresher.refresh()
            try await api.send(job)
            return .sent
        } catch .conflict(let serverUpdatedAt) {
            guard job.createdAt >= serverUpdatedAt else {
                Log.sync.info("Job \(job.id, privacy: .public) lost conflict: fetching server state")
                return .serverWon(try await fetchSnapshotRefreshingSession())
            }
            Log.sync.info("Job \(job.id, privacy: .public) won conflict: resending")
            try await api.send(job)
            return .sent
        } catch {
            throw error
        }
    }

    private func handleSendFailure(_ error: SyncError, for job: SyncJob) async {
        switch error {
        case .cancelled:
            return
        case .offline:
            Log.sync.info("Drain stopped: offline")
        default:
            Log.sync.error("Job \(job.id, privacy: .public) failed: \(error.description, privacy: .public)")
            do {
                try await jobRepository.recordFailure(jobID: job.id, failure: error.description)
            } catch {
                Log.sync.error("Failed to record failure: \(String(describing: error), privacy: .public)")
            }
        }
    }

    // MARK: Initial load

    private func runInitialLoad() async throws(SyncError) {
        let task: Task<Result<Void, SyncError>, Never>
        if let initialLoadTask {
            task = initialLoadTask
        } else {
            task = Task { await self.fetchAndMergeSnapshot() }
            initialLoadTask = task
        }
        let result = await task.value
        if initialLoadTask == task {
            initialLoadTask = nil
        }
        try result.get()
    }

    private func fetchAndMergeSnapshot() async -> Result<Void, SyncError> {
        let snapshot: RemoteSnapshot
        do {
            snapshot = try await fetchSnapshotRefreshingSession()
        } catch {
            return .failure(error)
        }
        guard !Task.isCancelled else { return .failure(.cancelled) }
        do {
            try await jobRepository.mergeRemoteSnapshot(snapshot)
        } catch {
            return .failure(.storageFailure(String(describing: error)))
        }
        return .success(())
    }

    private func fetchSnapshotRefreshingSession() async throws(SyncError) -> RemoteSnapshot {
        do {
            return try await api.fetchSnapshot()
        } catch .unauthorized {
            Log.sync.info("Snapshot request unauthorized: refreshing session")
            try await sessionRefresher.refresh()
            return try await api.fetchSnapshot()
        } catch {
            throw error
        }
    }

    // MARK: Reset

    private func performReset() async -> RepositoryError? {
        Log.sync.info("Resetting local data")
        await stop()
        isRerunRequested = false
        latestJobs = []
        lastFingerprint = nil

        do {
            try await localDataResetter.resetAllData()
        } catch {
            start()
            return error
        }
        start()
        do {
            try await runInitialLoad()
        } catch {
            Log.sync.error("Reload after reset failed: \(error.description, privacy: .public)")
            return .resetReloadFailed(error)
        }
        return nil
    }
}
