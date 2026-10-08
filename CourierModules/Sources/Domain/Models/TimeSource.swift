public import Foundation

public protocol TimeSource: Sendable {
    func now() -> Date
    func sleep(until deadline: Date) async throws
}

public struct SystemTimeSource: TimeSource {
    public init() {}

    public func now() -> Date {
        Date()
    }

    public func sleep(until deadline: Date) async throws {
        try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
    }
}
