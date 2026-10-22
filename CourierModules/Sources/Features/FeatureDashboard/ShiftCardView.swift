import DesignSystem
import Domain
import SwiftUI

struct ShiftCardView: View {
    let model: ShiftCardViewModel
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .title2) private var progressDiameter = 72
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
            VStack(alignment: .leading, spacing: 24) {
                header(for: summary)

                metricsSection(for: summary)

                actions(for: summary)
            }
            .padding(24)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 28))
            .overlay {
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(Palette.mint.opacity(0.15), lineWidth: 1)
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
            startShiftButton
        case .active:
            activeShiftActions(for: summary)
        case .finished:
            reopenShiftButton
        }
    }

    private func statusTitle(for status: ShiftStatus) -> LocalizedStringResource {
        switch status {
        case .scheduled: .dashboardShiftCardStatusScheduled
        case .active: .dashboardShiftCardStatusActive
        case .finished: .dashboardShiftCardStatusFinished
        }
    }

    private func header(for summary: ShiftSummary) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Label(.dashboardShiftCardLabel, systemImage: "bicycle")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(cardSecondary)
                Text(statusTitle(for: summary.status))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(cardPrimary)
            }

            Spacer()
            Image(systemName: "location.north.line.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(cardAccent)
                .frame(width: 44, height: 44)
                .background(Palette.mint.opacity(0.15), in: Circle())
        }
    }
    
    private func progressView(for summary: ShiftSummary) -> some View {
        VStack(spacing: 12) {
            Text(.dashboardShiftCardStopsDone)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(cardSecondary)
                .kerning(0.5)
            
            ZStack {
                Circle()
                    .stroke(Palette.mint.opacity(0.15), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: min(max(summary.progress, 0), 1))
                    .stroke(
                        LinearGradient(
                            colors: [Palette.mint, Palette.mintHighlight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Palette.mintHighlight.opacity(0.4), radius: 4, x: 0, y: 2)

                HStack(spacing: 2) {
                    Text(summary.completedCount, format: .number)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(cardPrimary)
                        .contentTransition(.numericText())

                    Text(verbatim: "/\(summary.totalCount.formatted())")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(cardSecondary)
                        .kerning(2)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }
            .frame(width: progressDiameter, height: progressDiameter)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: summary.progress)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(.dashboardShiftCardProgress(summary.completedCount, summary.totalCount)))
        }
    }
    
    private func earningsView(for summary: ShiftSummary) -> some View {
        VStack(spacing: 18) {
            Text(.dashboardShiftCardEarnings)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(cardSecondary)
                .kerning(0.5)
            
            Text(summary.earnings, format: .currency(code: "GBP"))
                .font(.system(.largeTitle, design: .rounded, weight: .heavy).monospacedDigit())
                .foregroundStyle(cardPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText(value: NSDecimalNumber(decimal: summary.earnings).doubleValue))
        }
    }

    private func metricsSection(for summary: ShiftSummary) -> some View {
        HStack(alignment: .top, spacing: 0) {
            progressView(for: summary)
            
            Spacer()
            
            Divider()
                .padding(.vertical, 12)
            
            Spacer()
            
            earningsView(for: summary)
        }
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(DashboardAccessibility.shiftMetrics)
    }

    private var startShiftButton: some View {
        PrimaryButton(.dashboardShiftCardStartButton, systemImage: "play.fill") {
            Task { await model.startShift() }
        }
        .disabled(model.isPerformingAction)
        .accessibilityIdentifier(DashboardAccessibility.startShiftButton)
    }

    @ViewBuilder
    private func activeShiftActions(for summary: ShiftSummary) -> some View {
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
    }

    private var reopenShiftButton: some View {
        PrimaryButton(.dashboardShiftCardReopenButton, systemImage: "arrow.counterclockwise") {
            Task { await model.reopenShift() }
        }
        .disabled(model.isPerformingAction)
        .accessibilityIdentifier(DashboardAccessibility.reopenShiftButton)
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
            
            Spacer().layoutPriority(1)
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
