import DesignSystem
import Domain
import SwiftUI

struct ShiftCardView: View {
    let model: ShiftCardViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isEndConfirmationPresented = false

    private var isDark: Bool { colorScheme == .dark }
    private var cardAccent: Color { Palette.accent }
    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: isDark
                ? [Color(red: 0.06, green: 0.14, blue: 0.11), Palette.surfaceCard]
                : [
                    Color(red: 235 / 255, green: 248 / 255, blue: 242 / 255),
                    Color(red: 244 / 255, green: 251 / 255, blue: 247 / 255),
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
                        .background(Palette.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                }
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.mint.opacity(0.12))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Palette.mint, Palette.mintHighlight],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: Palette.mintHighlight.opacity(0.35), radius: 3)
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
                    .strokeBorder(Palette.mint.opacity(0.12), lineWidth: 1)
            }
            .padding(1)
            .animation(.snappy, value: summary.earnings)
            .confirmationDialog(
                Text(.dashboardShiftCardEndConfirmationTitle),
                isPresented: $isEndConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(String(localized: .dashboardShiftCardEndConfirmButton)) {
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
            PrimaryButton(.dashboardShiftCardEndButton, systemImage: "stop.fill") {
                isEndConfirmationPresented = true
            }
            .disabled(isBlocked)
            .accessibilityIdentifier(DashboardAccessibility.endShiftButton)
            if summary.hasTaskInTransit {
                Label(.dashboardShiftCardEndBlockedMessage, systemImage: "info.circle")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.warning)
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

#if DEBUG
    import DomainTestSupport

    struct ShiftCardPreview: View {
        private let model: ShiftCardViewModel

        init(_ summary: ShiftSummary) {
            model = ShiftCardViewModel(previewSummary: summary)
        }

        var body: some View {
            ShiftCardView(model: model)
                .padding()
        }
    }

    #Preview("Scheduled") {
        ShiftCardPreview(.fixture(status: .scheduled))
    }

    #Preview("Active") {
        ShiftCardPreview(.fixture(status: .active, earnings: 42, completedCount: 2))
    }

    #Preview("Active, in transit") {
        ShiftCardPreview(.fixture(status: .active, earnings: 42, completedCount: 2, hasTaskInTransit: true))
    }

    #Preview("Finished") {
        ShiftCardPreview(.fixture(status: .finished, earnings: 84, completedCount: 3, totalCount: 3))
    }

    #Preview("Dark") {
        ShiftCardPreview(.fixture(status: .active, earnings: 42, completedCount: 2))
            .preferredColorScheme(.dark)
    }
#endif
