public import SwiftUI

public struct PrimaryButton: View {
    public enum Role {
        case standard
        case success
        case destructive
    }

    private let title: LocalizedStringResource
    private let role: Role
    private let action: () -> Void

    public init(_ title: LocalizedStringResource, role: Role = .standard, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(tint)
    }

    private var tint: Color {
        switch role {
        case .standard: Palette.accent
        case .success: Palette.success
        case .destructive: Palette.danger
        }
    }
}
