import Foundation

enum StudyCooldown {
    static func remainingSeconds(until availability: Date?, now: Date) -> Int {
        guard let availability else { return 0 }
        let interval = availability.timeIntervalSince(now)
        guard interval.isFinite, interval > 0 else { return 0 }
        let rounded = interval.rounded(.up)
        guard rounded <= Double(Int.max) else { return Int.max }
        return Int(rounded)
    }

    static func formattedRemaining(until availability: Date?, now: Date) -> String {
        format(seconds: remainingSeconds(until: availability, now: now))
    }

    static func format(seconds: Int) -> String {
        let nonNegativeSeconds = max(0, seconds)
        let hours = nonNegativeSeconds / 3_600
        let minutes = (nonNegativeSeconds % 3_600) / 60
        let seconds = nonNegativeSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
