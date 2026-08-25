import SwiftUI

/// Time-remaining math and formatting. Countdown strings are always computed
/// from an explicit `now` (the timeline entry date in the widget) rather than
/// `Date()`, so entries stay correct as the timeline advances.
enum Countdown {
    static func remaining(from now: Date, to due: Date) -> (days: Int, hours: Int, isOverdue: Bool) {
        let interval = due.timeIntervalSince(now)
        if interval < 0 {
            return (0, 0, true)
        }
        let totalHours = Int(interval / 3600)
        return (totalHours / 24, totalHours % 24, false)
    }

    /// `12d 4h`, `0d 9h`, `<1h` under one hour, `overdue` for past dates.
    static func label(from now: Date, to due: Date) -> String {
        let r = remaining(from: now, to: due)
        if r.isOverdue {
            return "overdue"
        }
        if r.days == 0 && r.hours == 0 {
            return "<1h"
        }
        return "\(r.days)d \(r.hours)h"
    }
}

enum Urgency {
    case calm       // more than 7 days out
    case soon       // 1 to 7 days
    case critical   // under 24 hours
    case overdue

    init(from now: Date, to due: Date) {
        let interval = due.timeIntervalSince(now)
        if interval < 0 {
            self = .overdue
        } else if interval < 24 * 3600 {
            self = .critical
        } else if interval <= 7 * 24 * 3600 {
            self = .soon
        } else {
            self = .calm
        }
    }

    var color: Color {
        switch self {
        case .calm: .secondary
        case .soon: .orange
        case .critical: .red
        case .overdue: .red
        }
    }
}
