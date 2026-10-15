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
                    .foregroundStyle(.white)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.18))
                        Capsule()
                            .fill(LinearGradient(colors: [.cyan, .white], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geometry.size.width * min(max(summary.progress, 0), 1))
                    }
                }
                .frame(height: 8)
                Text(.dashboardShiftCardProgress(summary.completedCount, summary.totalCount))
                    .font(Typography.body)
                    .foregroundStyle(.white.opacity(0.75))
                HStack {
                    Text(.dashboardShiftCardEarnings)
                    Spacer()
                    Text(summary.earnings, format: .currency(code: "GBP"))
                        .font(Typography.metric.monospacedDigit())
                        .contentTransition(.numericText(value: NSDecimalNumber(decimal: summary.earnings).doubleValue))
                }
                .font(Typography.headline)
                .foregroundStyle(.white)
                actions(for: summary)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color(red: 0.09, green: 0.17, blue: 0.31), Color(red: 0.16, green: 0.27, blue: 0.46)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22)
            )
            .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: 8)
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
                    .foregroundStyle(.yellow)
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
