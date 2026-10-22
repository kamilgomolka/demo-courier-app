import DesignSystem
import Domain
import SwiftUI

struct TaskRowView: View {
    let task: DeliveryTask

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            icon
            labels
        }
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
    
    private var icon: some View {
        Image(systemName: task.status == .inTransit ? "bicycle" : "shippingbox.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(statusColor)
            .frame(width: 38, height: 38)
            .background(statusColor.opacity(0.12), in: .circle)
            .padding(.top, 4)
    }
    
    private var labels: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .frame(maxWidth: .infinity)
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
