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
        Label(title, systemImage: systemImage)
            .font(Typography.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15), in: Capsule())
    }
}
