import DesignSystem
public import Domain
public import SwiftUI

public struct SettingsView: View {
    @State private var model: SettingsViewModel
    @State private var isResetConfirmationPresented = false

    public init(
        conditionsStore: any NetworkConditionsStore,
        jobRepository: any SyncJobRepository,
        syncController: any SyncControlling
    ) {
        _model = State(
            initialValue: SettingsViewModel(
                conditionsStore: conditionsStore,
                jobRepository: jobRepository,
                syncController: syncController
            )
        )
    }

    public var body: some View {
        Form {
            simulationSection
            dataSection
            jobsSection
        }
        .navigationTitle(Text(.settingsNavigationTitle))
        .task { await model.run() }
        .scrollContentBackground(.hidden)
        .background(Palette.backgroundPrimary)
        .tint(Palette.accent)
        .alert(
            Text(.settingsResetFailureTitle),
            isPresented: Binding(
                get: { model.resetFailure != nil },
                set: { isPresented in
                    if !isPresented {
                        model.dismissResetFailure()
                    }
                }
            )
        ) {
            Button(String(localized: .settingsResetFailureDismissButton)) {}
        } message: {
            if case .resetReloadFailed? = model.resetFailure {
                Text(.settingsResetReloadFailureMessage)
            } else {
                Text(.settingsResetFailureMessage)
            }
        }
    }

    private var simulationSection: some View {
        Section {
            Picker(
                selection: Binding(
                    get: {
                        model.conditions.isOffline
                            ? SimulationChoice.offline : .failure(model.conditions.simulatedFailure)
                    },
                    set: { choice in
                        Task {
                            switch choice {
                            case .offline:
                                model.setSimulatedFailure(.none)
                                await model.setOffline(true)
                            case .failure(let failure):
                                model.setSimulatedFailure(failure)
                                await model.setOffline(false)
                            }
                        }
                    }
                )
            ) {
                Text(.settingsFailureNone).tag(SimulationChoice.failure(.none))
                Text(.settingsSimulationOffline).tag(SimulationChoice.offline)
                ForEach(SimulatedFailure.allCases.filter { $0 != .none }, id: \.self) { failure in
                    Text(title(for: failure)).tag(SimulationChoice.failure(failure))
                }
            } label: {
                Label(.settingsSimulationFailure, systemImage: "wifi.exclamationmark")
            }
            .accessibilityIdentifier(SettingsAccessibility.simulatedFailurePicker)
            VStack(alignment: .leading, spacing: 18) {
                Label(.settingsSimulationLatency, systemImage: "timer")
                latencyStepper(
                    title: .settingsSimulationLatencyFrom,
                    value: Binding(
                        get: { model.conditions.latencyRange.lowerBound },
                        set: { model.setLatencyLowerBound($0) }
                    )
                )
                .padding(.leading, 32)
                latencyStepper(
                    title: .settingsSimulationLatencyTo,
                    value: Binding(
                        get: { model.conditions.latencyRange.upperBound },
                        set: { model.setLatencyUpperBound($0) }
                    )
                )
                .padding(.leading, 32)
            }
        } header: {
            Text(.settingsSimulationHeader)
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                isResetConfirmationPresented = true
            } label: {
                Label(.settingsResetButton, systemImage: "arrow.counterclockwise")
                    .foregroundStyle(Palette.accent)
            }
            .disabled(model.isResetting)
            .accessibilityIdentifier(SettingsAccessibility.resetButton)
            .confirmationDialog(
                Text(.settingsResetConfirmationTitle),
                isPresented: $isResetConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(String(localized: .settingsResetConfirmButton)) {
                    Task { await model.resetLocalData() }
                }
                .accessibilityIdentifier(SettingsAccessibility.resetConfirmButton)
            } message: {
                Text(.settingsResetConfirmationMessage)
            }
        }
    }

    private var jobsSection: some View {
        Section {
            Button {
                Task { await model.syncNow() }
            } label: {
                Label(.settingsSyncNowButton, systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(model.jobs.isEmpty ? Palette.textSecondary : Palette.accent)
            }
            .disabled(model.jobs.isEmpty)
            .accessibilityIdentifier(SettingsAccessibility.syncNowButton)
            if model.jobs.isEmpty {
                Label(.settingsJobsEmpty, systemImage: "checkmark.circle")
                    .foregroundStyle(Palette.textSecondary)
            }
            ForEach(model.jobs) { job in
                SyncJobRowView(job: job)
                    .accessibilityIdentifier(SettingsAccessibility.job(id: job.id.uuidString))
            }
        } header: {
            Text(.settingsJobsHeader)
        }
    }

    private func latencyStepper(title: LocalizedStringResource, value: Binding<Double>) -> some View {
        Stepper(value: value, in: SettingsViewModel.latencyBounds, step: 0.5) {
            HStack {
                Text(title)
                Spacer()
                HStack(spacing: 0) {
                    Text(value.wrappedValue, format: .number.precision(.fractionLength(1)))
                    Text(.settingsSimulationSecondsSuffix)
                }
                .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    private func title(for failure: SimulatedFailure) -> LocalizedStringResource {
        switch failure {
        case .none: .settingsFailureNone
        case .timeout: .settingsFailureTimeout
        case .connectionLost: .settingsFailureConnectionLost
        case .serverError: .settingsFailureServerError
        case .serviceUnavailable: .settingsFailureServiceUnavailable
        case .tooManyRequests: .settingsFailureTooManyRequests
        case .unauthorized: .settingsFailureUnauthorized
        case .conflict: .settingsFailureConflict
        }
    }
}

private enum SimulationChoice: Hashable {
    case offline
    case failure(SimulatedFailure)
}

private struct SyncJobRowView: View {
    let job: SyncJob

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kindTitle)
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            HStack {
                Text(.settingsJobsAttempts(job.attemptCount))
                Spacer()
                Text(job.notBefore, format: .dateTime.hour().minute().second())
            }
            .font(Typography.caption)
            .foregroundStyle(Palette.textSecondary)
            if let lastFailure = job.lastFailure {
                Text(verbatim: lastFailure)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.warning)
            }
        }
    }

    private var kindTitle: LocalizedStringResource {
        switch job.kind {
        case .updateStatus(let taskID, let status, _):
            .settingsJobsUpdateStatus(taskID, status.rawValue)
        case .reorder(let orderedTaskIDs):
            .settingsJobsReorder(orderedTaskIDs.count)
        }
    }
}

#if DEBUG
    import DomainTestSupport

    private func settingsPreview(
        conditions: NetworkConditions = NetworkConditions(),
        jobs: [SyncJob] = []
    ) -> some View {
        let conditionsStore = FakeNetworkConditionsStore(conditions)
        let jobRepository = FakeSyncJobRepository()
        jobRepository.jobs.send(jobs)
        return NavigationStack {
            SettingsView(
                conditionsStore: conditionsStore,
                jobRepository: jobRepository,
                syncController: FakeSyncController()
            )
        }
    }

    #Preview("With pending job") {
        settingsPreview(
            conditions: NetworkConditions(isOffline: true, latencyRange: 2...5, simulatedFailure: .none),
            jobs: [
                SyncJob(
                    kind: .updateStatus(taskID: "task-1", status: .delivered, exceptionReason: nil),
                    createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                    notBefore: Date(timeIntervalSince1970: 1_800_000_300),
                    attemptCount: 2,
                    lastFailure: "Request timed out"
                )
            ]
        )
    }

    #Preview("No pending jobs") {
        settingsPreview()
    }
#endif
