public import SwiftUI

public struct EmptyStateView: View {
    public struct Action {
        let title: LocalizedStringResource
        let handler: () -> Void

        public init(_ title: LocalizedStringResource, handler: @escaping () -> Void) {
            self.title = title
            self.handler = handler
        }
    }

    private let systemImage: String
    private let title: LocalizedStringResource
    private let message: LocalizedStringResource?
    private let action: Action?

    public init(
        systemImage: String,
        title: LocalizedStringResource,
        message: LocalizedStringResource? = nil,
        action: Action? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let message {
                Text(message)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }
        } actions: {
            if let action {
                PrimaryButton(action.title, action: action.handler)
            }
        }
    }
}

#if DEBUG
    #Preview("With action") {
        EmptyStateView(
            systemImage: "shippingbox",
            title: "No deliveries",
            message: "New deliveries will appear here.",
            action: EmptyStateView.Action("Refresh") {}
        )
        .frame(width: 320, height: 280)
        .padding()
    }

    #Preview("Without action") {
        EmptyStateView(
            systemImage: "clock",
            title: "No history",
            message: "Completed deliveries will appear here."
        )
        .frame(width: 320, height: 280)
        .padding()
    }

    #Preview("Dark") {
        EmptyStateView(
            systemImage: "shippingbox",
            title: "No deliveries",
            message: "New deliveries will appear here."
        )
        .preferredColorScheme(.dark)
        .frame(width: 320, height: 280)
        .padding()
    }

    #Preview("Accessibility") {
        EmptyStateView(
            systemImage: "shippingbox",
            title: "No deliveries",
            message: "New deliveries will appear here."
        )
        .dynamicTypeSize(.accessibility3)
        .frame(width: 320, height: 280)
        .padding()
    }
#endif
