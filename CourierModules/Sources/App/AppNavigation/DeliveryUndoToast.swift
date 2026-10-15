import DesignSystem
import Domain
import SwiftUI

struct DeliveryUndoToast: View {
    let pendingUndo: PendingDeliveryUndo
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Palette.success)
            VStack(alignment: .leading, spacing: 2) {
                Text(.navigationUndoToastDelivered(pendingUndo.task.recipientName))
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text(timerInterval: countdownInterval, countsDown: true, showsHours: false)
                    .font(Typography.caption.monospacedDigit())
                    .foregroundStyle(Palette.textSecondary)
                    .contentTransition(.numericText(countsDown: true))
            }
            Spacer(minLength: 4)
            Button(action: undo) {
                Text(.navigationUndoToastUndo)
                    .font(Typography.headline)
            }
            .tint(Palette.accent)
            .accessibilityIdentifier("delivery.undoToast.undoButton")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .contain)
    }

    private var countdownInterval: ClosedRange<Date> {
        Date.now...max(Date.now, pendingUndo.deadline)
    }
}
