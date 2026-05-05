import Foundation

final class Time: Resource {
    private let startDate = Date()

    var elapsed: TimeInterval {
        Date().timeIntervalSince(startDate)
    }
}
