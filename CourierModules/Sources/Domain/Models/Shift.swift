public import Foundation

public enum ShiftStatus: String, Codable, Sendable {
    case scheduled
    case active
    case finished
}

public struct Shift: Equatable, Identifiable, Sendable {
    public var id: ShiftID
    public var status: ShiftStatus
    public var startDate: Date?
    public var endDate: Date?

    public init(id: ShiftID, status: ShiftStatus, startDate: Date? = nil, endDate: Date? = nil) {
        self.id = id
        self.status = status
        self.startDate = startDate
        self.endDate = endDate
    }
}
