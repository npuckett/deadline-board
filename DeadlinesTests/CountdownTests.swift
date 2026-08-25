import XCTest
@testable import Deadlines

final class CountdownTests: XCTestCase {
    // A fixed reference point so tests are deterministic.
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: remaining

    func testExactlyTwentyFourHours() {
        let r = Countdown.remaining(from: now, to: now.addingTimeInterval(24 * 3600))
        XCTAssertEqual(r.days, 1)
        XCTAssertEqual(r.hours, 0)
        XCTAssertFalse(r.isOverdue)
    }

    func testFiftyNineMinutes() {
        let r = Countdown.remaining(from: now, to: now.addingTimeInterval(59 * 60))
        XCTAssertEqual(r.days, 0)
        XCTAssertEqual(r.hours, 0)
        XCTAssertFalse(r.isOverdue)
    }

    func testPastDue() {
        let r = Countdown.remaining(from: now, to: now.addingTimeInterval(-60))
        XCTAssertTrue(r.isOverdue)
    }

    func testTwelveDaysFourHours() {
        let r = Countdown.remaining(from: now, to: now.addingTimeInterval(12 * 24 * 3600 + 4 * 3600))
        XCTAssertEqual(r.days, 12)
        XCTAssertEqual(r.hours, 4)
        XCTAssertFalse(r.isOverdue)
    }

    // MARK: label

    func testLabelFormats() {
        XCTAssertEqual(Countdown.label(from: now, to: now.addingTimeInterval(12 * 24 * 3600 + 4 * 3600)), "12d 4h")
        XCTAssertEqual(Countdown.label(from: now, to: now.addingTimeInterval(9 * 3600)), "0d 9h")
        XCTAssertEqual(Countdown.label(from: now, to: now.addingTimeInterval(24 * 3600)), "1d 0h")
        XCTAssertEqual(Countdown.label(from: now, to: now.addingTimeInterval(59 * 60)), "<1h")
        XCTAssertEqual(Countdown.label(from: now, to: now.addingTimeInterval(-1)), "overdue")
        // Exactly due is not yet overdue.
        XCTAssertEqual(Countdown.label(from: now, to: now), "<1h")
    }

    // MARK: urgency

    func testUrgencyBoundaries() {
        // Under 24 hours is critical; exactly 24 hours is not.
        XCTAssertEqual(Urgency(from: now, to: now.addingTimeInterval(24 * 3600 - 1)), .critical)
        XCTAssertEqual(Urgency(from: now, to: now.addingTimeInterval(24 * 3600)), .soon)
        // 1 to 7 days is soon; past 7 days is calm.
        XCTAssertEqual(Urgency(from: now, to: now.addingTimeInterval(7 * 24 * 3600)), .soon)
        XCTAssertEqual(Urgency(from: now, to: now.addingTimeInterval(7 * 24 * 3600 + 1)), .calm)
        XCTAssertEqual(Urgency(from: now, to: now.addingTimeInterval(-1)), .overdue)
    }
}
