public import SwiftUI

public struct PrimaryButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var feedbackTrigger = false

    private let title: LocalizedStringResource
    private let systemImage: String?
    private let action: () -> Void

    public init(
        _ title: LocalizedStringResource,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button {
            feedbackTrigger.toggle()
            action()
        } label: {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(Typography.headline)
            .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(MintButtonStyle(colors: colors, glow: Palette.accent))
        .sensoryFeedback(.impact(weight: .medium), trigger: feedbackTrigger)
    }

    private var colors: [Color] {
        colorScheme == .dark
            ? [Palette.accent, Palette.mint]
            : [Palette.mint, Color(red: 0, green: 122 / 255, blue: 80 / 255)]
    }
}

private struct MintButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.displayScale) private var displayScale

    let colors: [Color]
    let glow: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom),
                in: .capsule
            )
            .shadow(color: glow.opacity(isEnabled ? 0.3 : 0), radius: 14, x: 0, y: 7)
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

#if DEBUG
    #Preview("Standard") {
        PrimaryButton("Continue", systemImage: "arrow.right") {}
            .padding()
    }

    #Preview("Disabled") {
        PrimaryButton("Continue", systemImage: "arrow.right") {}
            .disabled(true)
            .padding()
    }

    #Preview("Dark") {
        PrimaryButton("Continue", systemImage: "arrow.right") {}
            .preferredColorScheme(.dark)
            .padding()
    }

    #Preview("Accessibility") {
        PrimaryButton("Continue", systemImage: "arrow.right") {}
            .dynamicTypeSize(.accessibility3)
            .padding()
    }
#endif
