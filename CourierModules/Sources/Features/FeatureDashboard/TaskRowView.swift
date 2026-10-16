import DesignSystem
import Domain
import SwiftUI

struct TaskRowView: View {
    let task: DeliveryTask

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: task.status == .inTransit ? "bicycle" : "shippingbox.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(statusColor)
                .frame(width: 38, height: 38)
                .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 9) {
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
                Label(task.deliveryAddress, systemImage: "mappin")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
                Label(task.packageSummary, systemImage: "cube.box")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
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
