import DesignSystem
import Domain
import SwiftUI

struct ExceptionReportSheet: View {
    @State private var draft = ExceptionDraft()
    @FocusState private var isDetailsFieldFocused: Bool
    let onSave: (ExceptionReason) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            reportForm
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: .deliveryExceptionCancelButton), action: onCancel)
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        saveButton
                    }
                }
                .sensoryFeedback(.selection, trigger: draft.choice)
                .animation(.spring(response: 0.32, dampingFraction: 0.78), value: draft.choice)
                .onChange(of: draft.choice) { _, choice in
                    isDetailsFieldFocused = choice == .other
                }
        }
    }

    private func choiceCard(_ choice: ExceptionDraft.Choice) -> some View {
        let isSelected = draft.choice == choice

        return Button {
            draft.choice = choice
        } label: {
            choiceCardLabel(for: choice, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(DeliveryAccessibility.exceptionOption(String(describing: choice)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func symbol(for choice: ExceptionDraft.Choice) -> String {
        switch choice {
        case .customerNoShow: "person.crop.circle.badge.xmark"
        case .addressNotFound: "mappin.slash"
        case .packageDamaged: "shippingbox.and.arrow.backward"
        case .other: "ellipsis.bubble"
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

    private var choiceGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            ForEach(ExceptionDraft.Choice.allCases, id: \.self) { choice in
                choiceCard(choice)
            }
        }
        .padding(.horizontal)
    }

    private var detailsField: some View {
        TextField(text: $draft.details, axis: .vertical) {
            Text(.deliveryExceptionDetailsPlaceholder)
        }
        .lineLimit(3...5)
        .padding(12)
        .background(Palette.surfaceCard, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .focused($isDetailsFieldFocused)
        .accessibilityIdentifier(DeliveryAccessibility.exceptionDetailsField)
    }

    private var saveButton: some View {
        Button {
            guard let reason = draft.reason else { return }
            onSave(reason)
        } label: {
            Label(.deliveryExceptionSaveButton, systemImage: "checkmark")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.accent)
        .disabled(draft.reason == nil)
        .accessibilityIdentifier(DeliveryAccessibility.exceptionSaveButton)
    }

    private var reportForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(.deliveryExceptionTitle)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)

                choiceGrid

                if draft.choice == .other {
                    detailsField
                }
            }
            .padding(.top, 4)
        }
    }

    private func choiceCardLabel(for choice: ExceptionDraft.Choice, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol(for: choice))
                .font(.title3.weight(.semibold))
                .foregroundStyle(isSelected ? Palette.accent : Palette.textSecondary)
            Text(title(for: choice))
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(14)
        .background(Palette.surfaceCard, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? Palette.accent : .clear, lineWidth: 2)
        }
        .scaleEffect(isSelected ? 1.02 : 1)
    }
}

#if DEBUG
    private extension ExceptionReportSheet {
        init(
            previewDraft: ExceptionDraft,
            onSave: @escaping (ExceptionReason) -> Void,
            onCancel: @escaping () -> Void
        ) {
            _draft = State(initialValue: previewDraft)
            self.onSave = onSave
            self.onCancel = onCancel
        }
    }

    #Preview("Customer no show") {
        ExceptionReportSheet(previewDraft: ExceptionDraft(), onSave: { _ in }, onCancel: {})
    }

    #Preview("Other with details") {
        ExceptionReportSheet(
            previewDraft: ExceptionDraft(choice: .other, details: "Recipient asked for the package to be returned."),
            onSave: { _ in },
            onCancel: {}
        )
    }
#endif
