public struct RemoteSnapshot: Equatable, Sendable {
    public var shift: Shift
    public var tasks: [DeliveryTask]

    public init(shift: Shift, tasks: [DeliveryTask]) {
        self.shift = shift
        self.tasks = tasks
    }
}
