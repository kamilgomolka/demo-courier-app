import Domain
import SwiftUI

struct ExceptionReportSheet: View {
    @State private var draft = ExceptionDraft()
    let onSave: (ExceptionReason) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker(selection: $draft.choice) {
                    ForEach(ExceptionDraft.Choice.allCases, id: \.self) { choice in
                        Text(title(for: choice))
                            .tag(choice)
                            .accessibilityIdentifier(DeliveryAccessibility.exceptionOption(String(describing: choice)))
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.inline)
                .labelsHidden()
                if draft.choice == .other {
                    TextField(text: $draft.details, axis: .vertical) {
                        Text(.deliveryExceptionDetailsPlaceholder)
                    }
                    .accessibilityIdentifier(DeliveryAccessibility.exceptionDetailsField)
                }
            }
            .navigationTitle(Text(.deliveryExceptionTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: .deliveryExceptionCancelButton), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: .deliveryExceptionSaveButton)) {
                        guard let reason = draft.reason else { return }
                        onSave(reason)
                    }
                    .disabled(draft.reason == nil)
                    .accessibilityIdentifier(DeliveryAccessibility.exceptionSaveButton)
                }
            }
        }
    }

    private func title(for choice: ExceptionDraft.Choice) -> LocalizedStringResource {
        switch choice {
        case .customerNoShow: .deliveryExceptionCustomerNoShow
        case .addressNotFound: .deliveryExceptionAddressNotFound
        case .packageDamaged: .deliveryExceptionPackageDamaged
        case .other: .deliveryExceptionOther
        }
    }
}
