import os

/// Structured logging for the Drift app using os.Logger.
/// View logs in Console.app with subsystem filter: "com.drift.health"
enum Log {
    static let database = Logger(subsystem: "com.drift.health", category: "database")
    static let healthKit = Logger(subsystem: "com.drift.health", category: "healthkit")
    static let weightTrend = Logger(subsystem: "com.drift.health", category: "weight-trend")
    static let foodLog = Logger(subsystem: "com.drift.health", category: "food-log")
    static let supplements = Logger(subsystem: "com.drift.health", category: "supplements")
    static let glucose = Logger(subsystem: "com.drift.health", category: "glucose")
    static let bodyComp = Logger(subsystem: "com.drift.health", category: "body-composition")
    static let app = Logger(subsystem: "com.drift.health", category: "app")
}
