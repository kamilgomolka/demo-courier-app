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
            }
        } actions: {
            if let action {
                PrimaryButton(action.title, action: action.handler)
            }
        }
    }
}
