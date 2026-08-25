import XCTest
@testable import Deadlines

final class DeadlineStoreTests: XCTestCase {
    var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeadlineStoreTests-\(UUID().uuidString)")
            .appendingPathComponent("deadlines.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        super.tearDown()
    }

    private func makeStore() -> DeadlineStore {
        DeadlineStore(fileURL: fileURL, reloadsWidgets: false)
    }

    // Whole-second dates: the ISO 8601 strategy truncates sub-second precision.
    private func date(_ secondsFromEpoch: TimeInterval) -> Date {
        Date(timeIntervalSince1970: secondsFromEpoch.rounded())
    }

    func testJSONRoundTrip() {
        let original = Deadline(
            title: "CHI paper",
            due: date(1_800_000_000),
            url: URL(string: "https://chi.acm.org"),
            notifyOffsets: [7 * 24 * 3600, 24 * 3600, 2 * 3600],
            isDone: false,
            createdAt: date(1_790_000_000)
        )
        let store = makeStore()
        store.add(original)

        let reloaded = DeadlineStore.load(from: fileURL)
        XCTAssertEqual(reloaded, [original])
    }

    func testRoundTripWithNilURL() {
        let original = Deadline(title: "No link", due: date(1_800_000_000), url: nil, notifyOffsets: [])
        var normalized = original
        normalized.createdAt = date(normalized.createdAt.timeIntervalSince1970)

        let store = makeStore()
        store.add(normalized)
        XCTAssertEqual(DeadlineStore.load(from: fileURL), [normalized])
    }

    func testLoadFromMissingFileReturnsEmpty() {
        XCTAssertEqual(DeadlineStore.load(from: fileURL), [])
        XCTAssertEqual(makeStore().deadlines, [])
    }

    func testUpcomingSortsAscendingAndKeepsOverdue() {
        let now = date(1_800_000_000)
        let overdue = Deadline(title: "Overdue", due: now.addingTimeInterval(-3600), notifyOffsets: [])
        let near = Deadline(title: "Near", due: now.addingTimeInterval(3600), notifyOffsets: [])
        let far = Deadline(title: "Far", due: now.addingTimeInterval(9 * 24 * 3600), notifyOffsets: [])
        let done = Deadline(title: "Done", due: now.addingTimeInterval(60), notifyOffsets: [], isDone: true)

        let store = makeStore()
        for deadline in [far, done, near, overdue] {
            store.add(deadline)
        }

        // Overdue stays at the top rather than disappearing; done is excluded.
        XCTAssertEqual(store.upcoming.map(\.title), ["Overdue", "Near", "Far"])
        XCTAssertEqual(DeadlineStore.upcoming(in: store.deadlines).map(\.title), ["Overdue", "Near", "Far"])
    }

    func testToggleDoneAndRemovePersist() {
        let deadline = Deadline(title: "Toggle me", due: date(1_800_000_000), notifyOffsets: [])
        let store = makeStore()
        store.add(deadline)

        store.toggleDone(id: deadline.id)
        XCTAssertTrue(DeadlineStore.load(from: fileURL).first!.isDone)
        XCTAssertEqual(store.upcoming, [])

        store.remove(id: deadline.id)
        XCTAssertEqual(DeadlineStore.load(from: fileURL), [])
    }

    func testUpdateReplacesMatchingID() {
        var deadline = Deadline(title: "Before", due: date(1_800_000_000), notifyOffsets: [])
        let store = makeStore()
        store.add(deadline)

        deadline.title = "After"
        store.update(deadline)
        XCTAssertEqual(DeadlineStore.load(from: fileURL).map(\.title), ["After"])
    }
}
