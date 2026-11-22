import Foundation

public enum TimeText {
    /// Short text for the menu bar: "45s", "20m", "1h 49m".
    /// Rounds up, so a session that just started at 20 minutes reads "20m".
    public static func menuBar(secondsLeft: TimeInterval) -> String {
        let seconds = max(0, Int(secondsLeft.rounded(.up)))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = (seconds + 59) / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }

    /// Full countdown for the panel: "19:42" or "1:49:05".
    public static func countdown(secondsLeft: TimeInterval) -> String {
        let seconds = max(0, Int(secondsLeft.rounded(.up)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    /// Button label for a session length: "5 min", "1 hr", "90 min".
    public static func length(minutes: Int) -> String {
        if minutes >= 60, minutes % 60 == 0 { return "\(minutes / 60) hr" }
        return "\(minutes) min"
    }
}
