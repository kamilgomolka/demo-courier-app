import DesignSystem
import Domain
import SwiftUI

struct ShiftCardView: View {
    let model: ShiftCardModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let summary = model.summary {
            VStack(alignment: .leading, spacing: 12) {
                Text(statusTitle(for: summary.status))
                    .font(Typography.title)
                    .foregroundStyle(Palette.textPrimary)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.textSecondary.opacity(0.14))
                        Capsule()
                            .fill(LinearGradient(colors: [Palette.accent, Color.cyan], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geometry.size.width * min(max(summary.progress, 0), 1))
                    }
                }
                .frame(height: 8)
                Text(.dashboardShiftCardProgress(summary.completedCount, summary.totalCount))
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
                HStack {
                    Text(.dashboardShiftCardEarnings)
                    Spacer()
                    Text(summary.earnings, format: .currency(code: "GBP"))
                        .font(Typography.metric.monospacedDigit())
                        .contentTransition(.numericText(value: NSDecimalNumber(decimal: summary.earnings).doubleValue))
                }
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
                actions(for: summary)
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(colorScheme == .light ? 0.06 : 0.18), radius: 12, x: 0, y: 5)
            .animation(.snappy, value: summary.earnings)
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
                    .foregroundStyle(colorScheme == .light ? Color.orange : .yellow)
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
