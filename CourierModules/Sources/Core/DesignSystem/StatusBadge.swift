public import SwiftUI

/// Compact capsule label that pairs an SF Symbol with a short status title.
public struct StatusBadge: View {
    private let title: LocalizedStringResource
    private let systemImage: String
    private let tint: Color

    public init(_ title: LocalizedStringResource, systemImage: String, tint: Color) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(Typography.caption)
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.15), in: Capsule())
    }
}

#if DEBUG
    #Preview("Variants") {
        VStack(alignment: .leading, spacing: 12) {
            StatusBadge("New", systemImage: "shippingbox.fill", tint: Palette.accent)
            StatusBadge("In transit", systemImage: "bicycle", tint: Palette.warning)
            StatusBadge("Delivered", systemImage: "checkmark.circle.fill", tint: Palette.success)
            StatusBadge("Exception", systemImage: "exclamationmark.triangle.fill", tint: Palette.danger)
        }
        .padding()
    }

    #Preview("Dark") {
        StatusBadge("In transit", systemImage: "bicycle", tint: Palette.warning)
            .preferredColorScheme(.dark)
            .padding()
    }

    #Preview("Accessibility") {
        StatusBadge("Exception", systemImage: "exclamationmark.triangle.fill", tint: Palette.danger)
            .dynamicTypeSize(.accessibility3)
            .padding()
    }
#endif
