import DesignSystem
public import Domain
public import SwiftUI

public struct SettingsView: View {
    @State private var model: SettingsModel
    @State private var isResetConfirmationPresented = false

    public init(
        conditionsStore: any NetworkConditionsStore,
        jobRepository: any SyncJobRepository,
        syncController: any SyncControlling
    ) {
        _model = State(
            initialValue: SettingsModel(
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
        .confirmationDialog(
            Text(.settingsResetConfirmationTitle),
            isPresented: $isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(String(localized: .settingsResetConfirmButton), role: .destructive) {
                Task { await model.resetLocalData() }
            }
            .accessibilityIdentifier(SettingsAccessibility.resetConfirmButton)
        } message: {
            Text(.settingsResetConfirmationMessage)
        }
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
            Text(.settingsResetFailureMessage)
        }
    }

    private var simulationSection: some View {
        Section {
            Toggle(
                isOn: Binding(
                    get: { model.conditions.isOffline },
                    set: { isOffline in Task { await model.setOffline(isOffline) } }
                )
            ) {
                Text(.settingsSimulationOffline)
            }
            .accessibilityIdentifier(SettingsAccessibility.offlineToggle)
            latencyStepper(
                title: .settingsSimulationLatencyFrom,
                value: Binding(
                    get: { model.conditions.latencyRange.lowerBound },
                    set: { model.setLatencyLowerBound($0) }
                )
            )
            latencyStepper(
                title: .settingsSimulationLatencyTo,
                value: Binding(
                    get: { model.conditions.latencyRange.upperBound },
                    set: { model.setLatencyUpperBound($0) }
                )
            )
            Picker(
                selection: Binding(
                    get: { model.conditions.simulatedFailure },
                    set: { model.setSimulatedFailure($0) }
                )
            ) {
                ForEach(SimulatedFailure.allCases, id: \.self) { failure in
                    Text(title(for: failure)).tag(failure)
                }
            } label: {
                Text(.settingsSimulationFailure)
            }
        } header: {
            Text(.settingsSimulationHeader)
        }
    }

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                isResetConfirmationPresented = true
            } label: {
                Text(.settingsResetButton)
            }
            .disabled(model.isResetting)
            .accessibilityIdentifier(SettingsAccessibility.resetButton)
        }
    }

    private var jobsSection: some View {
        Section {
            Button {
                Task { await model.syncNow() }
            } label: {
                Text(.settingsSyncNowButton)
            }
            .accessibilityIdentifier(SettingsAccessibility.syncNowButton)
            if model.jobs.isEmpty {
                Text(.settingsJobsEmpty)
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
        Stepper(value: value, in: SettingsModel.latencyBounds, step: 0.5) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue, format: .number.precision(.fractionLength(1)))
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
                    .foregroundStyle(Palette.danger)
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
