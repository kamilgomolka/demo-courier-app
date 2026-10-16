public import SwiftUI

public struct PrimaryButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var feedbackTrigger = false

    public enum Role {
        case standard
        case success
    }

    private let title: LocalizedStringResource
    private let systemImage: String?
    private let role: Role
    private let action: () -> Void

    public init(
        _ title: LocalizedStringResource,
        systemImage: String? = nil,
        role: Role = .standard,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
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
        .buttonStyle(MintButtonStyle(colors: colors, glow: tint))
        .sensoryFeedback(.impact(weight: .medium), trigger: feedbackTrigger)
    }

    private var colors: [Color] {
        switch role {
        case .standard:
            colorScheme == .dark
                ? [Palette.accent, Palette.mint]
                : [Palette.mint, Color(red: 0, green: 122 / 255, blue: 80 / 255)]
        case .success:
            [Palette.success, Palette.success]
        }
    }

    private var tint: Color {
        switch role {
        case .standard: Palette.accent
        case .success: Palette.success
        }
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
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1 / displayScale
                    )
            }
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
