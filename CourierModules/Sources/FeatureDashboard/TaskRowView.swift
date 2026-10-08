import DesignSystem
import Domain
import SwiftUI

struct TaskRowView: View {
    let task: DeliveryTask

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(task.recipientName)
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text(task.payout, format: .currency(code: "PLN"))
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
            }
            Text(task.deliveryAddress)
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
            Text(task.packageSummary)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
