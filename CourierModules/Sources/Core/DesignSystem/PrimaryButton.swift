public import SwiftUI

public struct PrimaryButton: View {
    @Environment(\.colorScheme) private var colorScheme

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
        Button(action: action) {
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
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .tint(tint)
    }

    private var tint: Color {
        switch role {
        case .standard: Palette.accent
        case .success: Palette.success
        }
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
