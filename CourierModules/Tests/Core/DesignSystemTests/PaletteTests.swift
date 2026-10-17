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

    @Test func electricMintPaletteMatchesBrandInBothAppearances() {
        for (scheme, accent, background) in [
            (ColorScheme.light, (0.000, 0.580, 0.380), (0.965, 0.973, 0.969)),
            (ColorScheme.dark, (0.000, 0.900, 0.600), (0.050, 0.065, 0.060)),
        ] {
            let resolvedAccent = resolved(Palette.accent, in: scheme)
            let resolvedBackground = resolved(Palette.backgroundPrimary, in: scheme)
            #expect(abs(Double(resolvedAccent.red) - accent.0) < 0.002)
            #expect(abs(Double(resolvedAccent.green) - accent.1) < 0.002)
            #expect(abs(Double(resolvedAccent.blue) - accent.2) < 0.002)
            #expect(abs(Double(resolvedBackground.red) - background.0) < 0.002)
            #expect(abs(Double(resolvedBackground.green) - background.1) < 0.002)
            #expect(abs(Double(resolvedBackground.blue) - background.2) < 0.002)
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
