import DesignSystem
import Domain
import SwiftUI

struct ShiftCardView: View {
    let model: ShiftCardModel

    var body: some View {
        if let summary = model.summary {
            VStack(alignment: .leading, spacing: 12) {
                Text(statusTitle(for: summary.status))
                    .font(Typography.title)
                    .foregroundStyle(Palette.textPrimary)
                ProgressView(value: summary.progress)
                    .tint(Palette.accent)
                Text(.dashboardShiftCardProgress(summary.completedCount, summary.totalCount))
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
                HStack {
                    Text(.dashboardShiftCardEarnings)
                    Spacer()
                    Text(summary.earnings, format: .currency(code: "GBP"))
                }
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
                actions(for: summary)
            }
            .padding()
            .background(Palette.surfaceCard, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private func actions(for summary: ShiftSummary) -> some View {
        switch summary.status {
        case .scheduled:
            PrimaryButton(.dashboardShiftCardStartButton) {
                Task { await model.startShift() }
            }
            .disabled(model.isPerformingAction)
            .accessibilityIdentifier(DashboardAccessibility.startShiftButton)
        case .active:
            PrimaryButton(.dashboardShiftCardEndButton, role: .destructive) {
                Task { await model.endShift() }
            }
            .disabled(summary.hasTaskInTransit || model.isPerformingAction)
            .accessibilityIdentifier(DashboardAccessibility.endShiftButton)
            if summary.hasTaskInTransit {
                Text(.dashboardShiftCardEndBlockedMessage)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.warning)
            }
        case .finished:
            EmptyView()
        }
    }

    private func statusTitle(for status: ShiftStatus) -> LocalizedStringResource {
        switch status {
        case .scheduled: .dashboardShiftCardStatusScheduled
        case .active: .dashboardShiftCardStatusActive
        case .finished: .dashboardShiftCardStatusFinished
        }
    }
}
