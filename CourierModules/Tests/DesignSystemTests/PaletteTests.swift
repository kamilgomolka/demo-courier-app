import SwiftUI
import Testing

@testable import DesignSystem

struct PaletteTests {
    nonisolated enum Token: CaseIterable, Sendable {
        case backgroundPrimary
        case surfaceCard
        case textPrimary
        case textSecondary
        case accent
        case success
        case danger
        case warning
    }

    private func color(for token: Token) -> Color {
        switch token {
        case .backgroundPrimary: Palette.backgroundPrimary
        case .surfaceCard: Palette.surfaceCard
        case .textPrimary: Palette.textPrimary
        case .textSecondary: Palette.textSecondary
        case .accent: Palette.accent
        case .success: Palette.success
        case .danger: Palette.danger
        case .warning: Palette.warning
        }
    }

    private func resolved(_ color: Color, in scheme: ColorScheme) -> Color.Resolved {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        return color.resolve(in: environment)
    }

    @Test(arguments: Token.allCases)
    func tokenResolvesToOpaqueColorInBothAppearances(token: Token) {
        for scheme in [ColorScheme.light, .dark] {
            #expect(resolved(color(for: token), in: scheme).opacity == 1)
        }
    }

    @Test func tokensDifferBetweenLightAndDark() {
        let lightBackground = resolved(Palette.backgroundPrimary, in: .light)
        let darkBackground = resolved(Palette.backgroundPrimary, in: .dark)
        let lightText = resolved(Palette.textPrimary, in: .light)
        let darkText = resolved(Palette.textPrimary, in: .dark)

        #expect(lightBackground.red != darkBackground.red)
        #expect(lightText.red != darkText.red)
    }
}
