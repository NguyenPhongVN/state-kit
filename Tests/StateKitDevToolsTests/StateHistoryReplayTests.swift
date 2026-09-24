import XCTest
@testable import StateKitDevTools

/// Thread-safe box for collecting results from @Sendable replay handlers.
private final class LockedBox<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    init(_ value: T) { _value = value }
    var value: T {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); defer { lock.unlock() }; _value = newValue }
    }
    func append(_ item: String) where T == [String] {
        lock.lock(); defer { lock.unlock() }
        _value.append(item)
    }
}

final class StateHistoryReplayTests: XCTestCase {

    private func makeHistory(actions: [String?]) -> InMemoryStateHistory {
        var history = InMemoryStateHistory()
        for action in actions {
            history.record(
                action: action,
                before: AnyCodable("before"),
                after: AnyCodable("after"),
                computeTime: 0.001
            )
        }
        return history
    }

    func testReplayExecutesApplicableActionsInOrder() async {
        var history = makeHistory(actions: ["loadUsers", "applyFilter", "saveProfile"])
        let received = LockedBox<[String]>([])

        let report = await history.replay { action in
            received.append(action)
            return true
        }

        XCTAssertEqual(received.value, ["loadUsers", "applyFilter", "saveProfile"])
        XCTAssertEqual(report.executed, ["loadUsers", "applyFilter", "saveProfile"])
        XCTAssertTrue(report.skipped.isEmpty)
        XCTAssertNil(report.failure)
    }

    func testReplayReportsUnhandledActionsAsSkipped() async {
        var history = makeHistory(actions: ["known", "unknown", "known"])
        let handled = LockedBox<[String]>([])

        let report = await history.replay { action in
            if action == "known" {
                handled.append(action)
                return true
            }
            return false
        }

        XCTAssertEqual(handled.value, ["known", "known"])
        XCTAssertEqual(report.skipped, ["unknown"])
        XCTAssertEqual(report.executed.count, 2)
        XCTAssertNil(report.failure)
    }

    func testReplayStopsAndReportsWhenHandlerThrows() async {
        var history = makeHistory(actions: ["first", "second", "third"])
        struct Boom: Error {}

        let report = await history.replay { action in
            if action == "second" { throw Boom() }
            return true
        }

        XCTAssertEqual(report.executed, ["first"])
        XCTAssertTrue(String(describing: report.failure).contains("Boom"))
    }

    func testReplaySkipsEntriesWithoutActions() async {
        var history = makeHistory(actions: [nil, "only-action", nil])
        let received = LockedBox<[String]>([])

        let report = await history.replay { action in
            received.append(action)
            return true
        }

        XCTAssertEqual(received.value, ["only-action"])
        XCTAssertEqual(report.skipped.count, 2, "entries without actions are reported as skipped")
    }
}
