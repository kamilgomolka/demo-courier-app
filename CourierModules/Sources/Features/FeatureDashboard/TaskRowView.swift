import DesignSystem
import Domain
import SwiftUI

struct TaskRowView: View {
    let task: DeliveryTask

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 14) {
                Image(systemName: task.status == .inTransit ? "bicycle" : "shippingbox.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: 38, height: 38)
                    .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                Text(task.recipientName)
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: 8)
                Text(task.payout, format: .currency(code: "GBP"))
                    .font(Typography.amount.monospacedDigit())
                    .foregroundStyle(Palette.textPrimary)
                    .frame(minWidth: 58, alignment: .trailing)
            }
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "mappin")
                    .frame(width: 38)
                Text(task.deliveryAddress)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(Typography.body)
            .foregroundStyle(Palette.textSecondary)
            HStack(spacing: 14) {
                Image(systemName: "cube.box")
                    .frame(width: 38)
                Text(task.packageSummary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(Typography.caption)
            .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var statusColor: Color {
        switch task.status {
        case .new: Palette.accent
        case .inTransit: Palette.warning
        case .delivered: Palette.accent
        case .exception: Palette.warning
        }
    }
}

#if DEBUG
    import DomainTestSupport

    #Preview("New") {
        TaskRowView(task: .fixture(status: .new))
            .padding()
    }

    #Preview("In transit") {
        TaskRowView(task: .fixture(status: .inTransit))
            .padding()
    }

    #Preview("Delivered") {
        TaskRowView(task: .fixture(status: .delivered))
            .padding()
    }

    #Preview("Exception") {
        TaskRowView(task: .fixture(status: .exception, exceptionReason: .customerNoShow))
            .padding()
    }

    #Preview("Long address") {
        var task = DeliveryTask.fixture()
        task.deliveryAddress = "Apartment 4B, 123 Very Long Street Name, Westminster, London SW1A 1AA"
        return TaskRowView(task: task)
            .padding()
    }

    #Preview("Dark") {
        TaskRowView(task: .fixture(status: .inTransit))
            .preferredColorScheme(.dark)
            .padding()
    }

    #Preview("Accessibility") {
        TaskRowView(task: .fixture(status: .new))
            .dynamicTypeSize(.accessibility3)
            .padding()
    }
#endif
