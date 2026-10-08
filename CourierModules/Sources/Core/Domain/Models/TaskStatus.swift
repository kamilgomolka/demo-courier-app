public enum TaskStatus: String, Codable, Sendable, CaseIterable {
    case new
    case inTransit
    case delivered
    case exception
}
