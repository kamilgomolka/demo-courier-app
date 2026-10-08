public enum ExceptionReason: Codable, Hashable, Sendable {
    case customerNoShow
    case addressNotFound
    case packageDamaged
    case other(details: String)
}
