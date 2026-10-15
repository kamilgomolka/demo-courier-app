import DesignSystem
import Domain
import SwiftUI

struct TaskRowView: View {
    let task: DeliveryTask

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(statusColor)
                .frame(width: 4)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.recipientName)
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer(minLength: 8)
                    Text(task.payout, format: .currency(code: "GBP"))
                        .font(Typography.amount.monospacedDigit())
                        .foregroundStyle(Palette.textPrimary)
                        .frame(minWidth: 58, alignment: .trailing)
                }
                Text(task.deliveryAddress)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
                Text(task.packageSummary)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var statusColor: Color {
        switch task.status {
        case .new: Palette.accent
        case .inTransit: Palette.warning
        case .delivered: Palette.success
        case .exception: Palette.danger
        }
    }
}
