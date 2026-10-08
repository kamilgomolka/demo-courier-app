import os

enum Log {
    static let sync = Logger(subsystem: "com.kamilgomolka.CourierApp", category: "sync")
    static let network = Logger(subsystem: "com.kamilgomolka.CourierApp", category: "network")
}
