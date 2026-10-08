public import Domain
import Foundation
import os

public actor SyncActor: SyncControlling {
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
    private let timeSource: any TimeSource

    private var observationTask: Task<Void, Never>?
    private var wakeTask: Task<Void, Never>?
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
        timeSource: any TimeSource = SystemTimeSource()
    ) {
        self.jobRepository = jobRepository
        self.localDataResetter = localDataResetter
        self.api = api
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
        let now = timeSource.now()
        guard let nextDeadline = latestJobs.map(\.notBefore).filter({ $0 > now }).min() else { return }
        wakeTask = Task { [weak self, timeSource] in
            do {
                try await timeSource.sleep(until: nextDeadline)
            } catch {
                return
            }
            await self?.wakeFired()
        }
    }

    private func wakeFired() {
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
        let jobs: [SyncJob]
        do {
            jobs = try await jobRepository.eligibleJobs(at: timeSource.now())
        } catch {
            Log.sync.error("Failed to read outbox: \(String(describing: error), privacy: .public)")
            return
        }
        var blockedTaskIDs: Set<TaskID> = []
        for job in jobs {
            guard !Task.isCancelled else { return }
            let taskID = job.kind.taskID
            if let taskID, blockedTaskIDs.contains(taskID) { continue }
            if job.attemptCount > 0 && !retryingFailedJobs {
                if let taskID { blockedTaskIDs.insert(taskID) }
                continue
            }
            do {
                try await api.send(job)
            } catch {
                await handleSendFailure(error, for: job)
                if error == .offline || error == .cancelled { return }
                if let taskID { blockedTaskIDs.insert(taskID) }
                continue
            }
            do {
                try await jobRepository.markSynced(jobID: job.id)
                Log.sync.info("Job \(job.id, privacy: .public) synced")
            } catch {
                Log.sync.error(
                    "Failed to acknowledge job \(job.id, privacy: .public): \(String(describing: error), privacy: .public)"
                )
                return
            }
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
            snapshot = try await api.fetchSnapshot()
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
        }
        return nil
    }
}
