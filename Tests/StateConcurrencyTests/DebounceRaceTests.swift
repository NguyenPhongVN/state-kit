import Testing
import StateConcurrency
import Foundation

// Spec 011 US2: concurrent debounce invocations within one interval must
// schedule exactly one trailing operation. The cancel/store pair in
// callAsFunction is not atomic at tip — interleaved calls can let two
// scheduled tasks both survive.

@Suite("DebouncedAction — contention")
struct DebounceRaceTests {

    final class HitCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var n = 0
        func hit() {
            lock.lock()
            n += 1
            lock.unlock()
        }
        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return n
        }
    }

    @Test("100 same-tick invocations collapse to one trailing execution")
    func raceCollapsesToOneOperation() async {
        let counter = HitCounter()
        let action = DebouncedAction(interval: .milliseconds(80)) { (_: Int) async in
            counter.hit()
        }

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    action(i)
                }
            }
        }

        // Debounce interval + margin.
        try? await Task.sleep(nanoseconds: 500_000_000)

        #expect(counter.count == 1, "one interval of simultaneous calls must schedule exactly one operation (got \(counter.count))")
    }
}
