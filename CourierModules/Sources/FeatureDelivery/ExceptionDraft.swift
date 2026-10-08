import Domain
import Foundation

struct ExceptionDraft: Equatable {
    enum Choice: CaseIterable, Hashable {
        case customerNoShow
        case addressNotFound
        case packageDamaged
        case other
    }

    var choice: Choice = .customerNoShow
    var details = ""

    var reason: ExceptionReason? {
        switch choice {
        case .customerNoShow:
            return .customerNoShow
        case .addressNotFound:
            return .addressNotFound
        case .packageDamaged:
            return .packageDamaged
        case .other:
            let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedDetails.isEmpty ? nil : .other(details: trimmedDetails)
        }
    }
}
