import Foundation

enum TimeFormatter {
    static func string(from seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else {
            return "00:00"
        }

        let totalSeconds = Int(seconds.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

