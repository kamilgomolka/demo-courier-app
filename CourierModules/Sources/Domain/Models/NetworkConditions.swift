public enum SimulatedFailure: String, Codable, Sendable, CaseIterable {
    case none
    case timeout
    case connectionLost
    case serverError
    case serviceUnavailable
    case tooManyRequests
}

public struct NetworkConditions: Equatable, Codable, Sendable {
    public var isOffline: Bool
    public var latencyRange: ClosedRange<Double>
    public var simulatedFailure: SimulatedFailure

    public init(
        isOffline: Bool = false,
        latencyRange: ClosedRange<Double> = 1...3,
        simulatedFailure: SimulatedFailure = .none
    ) {
        self.isOffline = isOffline
        self.latencyRange = latencyRange
        self.simulatedFailure = simulatedFailure
    }
}
