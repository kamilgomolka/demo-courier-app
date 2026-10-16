import DesignSystem
import Domain
import SwiftUI

struct ShiftCardView: View {
    let model: ShiftCardModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isEndConfirmationPresented = false

    private var isDark: Bool { colorScheme == .dark }
    private var cardAccent: Color { isDark ? Color(red: 1, green: 0.51, blue: 0.28) : Palette.accent }
    private var cardBackground: Color {
        isDark ? Color(red: 0.10, green: 0.14, blue: 0.15) : Color(red: 1, green: 0.96, blue: 0.91)
    }
    private var cardPrimary: Color { isDark ? .white : Palette.textPrimary }
    private var cardSecondary: Color { isDark ? .white.opacity(0.72) : Palette.textSecondary }

    var body: some View {
        if let summary = model.summary {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(.dashboardShiftCardLabel, systemImage: "bicycle")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(cardSecondary)
                        Text(statusTitle(for: summary.status))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(cardPrimary)
                    }
                    Spacer()
                    Image(systemName: "location.north.line.fill")
                        .font(.title2)
                        .foregroundStyle(cardAccent)
                        .frame(width: 48, height: 48)
                        .background(cardAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                }
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(cardAccent.opacity(isDark ? 0.22 : 0.16))
                            Capsule()
                                .fill(cardAccent)
                                .frame(width: geometry.size.width * min(max(summary.progress, 0), 1))
                        }
                    }
                    .frame(height: 8)
                    Text(.dashboardShiftCardProgress(summary.completedCount, summary.totalCount))
                        .font(Typography.caption)
                        .foregroundStyle(cardSecondary)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(.dashboardShiftCardEarnings)
                        .font(Typography.caption)
                        .foregroundStyle(cardSecondary)
                    Spacer()
                    Text(summary.earnings, format: .currency(code: "GBP"))
                        .font(.system(.title, design: .rounded, weight: .bold).monospacedDigit())
                        .foregroundStyle(cardPrimary)
                        .contentTransition(.numericText(value: NSDecimalNumber(decimal: summary.earnings).doubleValue))
                }
                actions(for: summary)
            }
            .padding(20)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(cardAccent.opacity(isDark ? 0 : 0.14), lineWidth: 1)
            }
            .animation(.snappy, value: summary.earnings)
            .confirmationDialog(
                Text(.dashboardShiftCardEndConfirmationTitle),
                isPresented: $isEndConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(String(localized: .dashboardShiftCardEndConfirmButton), role: .destructive) {
                    Task { await model.endShift() }
                }
                .accessibilityIdentifier(DashboardAccessibility.endShiftConfirmButton)
            } message: {
                Text(.dashboardShiftCardEndConfirmationMessage)
            }
        }
    }

    @ViewBuilder
    private func actions(for summary: ShiftSummary) -> some View {
        switch summary.status {
        case .scheduled:
            PrimaryButton(.dashboardShiftCardStartButton, systemImage: "play.fill") {
                Task { await model.startShift() }
            }
            .disabled(model.isPerformingAction)
            .accessibilityIdentifier(DashboardAccessibility.startShiftButton)
        case .active:
            let isBlocked = summary.hasTaskInTransit || model.isPerformingAction
            Button {
                isEndConfirmationPresented = true
            } label: {
                Label(.dashboardShiftCardEndButton, systemImage: "stop.fill")
                    .font(Typography.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(isBlocked ? cardSecondary : cardPrimary)
                    .background(
                        isDark
                            ? Color.white.opacity(isBlocked ? 0.07 : 0.12)
                            : Color.white.opacity(isBlocked ? 0.5 : 0.9),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isBlocked)
            .accessibilityIdentifier(DashboardAccessibility.endShiftButton)
            if summary.hasTaskInTransit {
                Label(.dashboardShiftCardEndBlockedMessage, systemImage: "info.circle")
                    .font(Typography.caption)
                    .foregroundStyle(isDark ? Color(red: 1, green: 0.72, blue: 0.42) : Palette.warning)
            }
        case .finished:
            PrimaryButton(.dashboardShiftCardReopenButton, systemImage: "arrow.counterclockwise") {
                Task { await model.reopenShift() }
            }
            .disabled(model.isPerformingAction)
            .accessibilityIdentifier(DashboardAccessibility.reopenShiftButton)
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
