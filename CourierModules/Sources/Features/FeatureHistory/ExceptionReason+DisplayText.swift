import Domain
import Foundation

extension ExceptionReason {
    var displayText: String {
        switch self {
        case .customerNoShow: String(localized: .historyReasonCustomerNoShow)
        case .addressNotFound: String(localized: .historyReasonAddressNotFound)
        case .packageDamaged: String(localized: .historyReasonPackageDamaged)
        case .other(let details): details
        }
    }
}
