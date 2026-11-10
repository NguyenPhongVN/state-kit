import Testing
import StateKit
import StateKitSupport
import StateKitTesting
import Foundation

// Spec 012 US5: StateKitSupport had 8 tests for 1739 LOC — the biggest coverage
// gap after StateKitTesting. Pin happy-path + teardown for the least-covered
// public hooks (bounded additions, not an exhaustive sweep).

@MainActor
@Suite("StateKitSupport — hook coverage")
struct StateKitSupportCoverageTests {

    // MARK: useCountdown

    @Test("useCountdown starts idle, runs, and cancels back to idle")
    func countdownLifecycle() {
        let h = StateTest()

        let controller = h.render {
            useCountdown(duration: 5, timeInterval: 10)
        }

        #expect(controller.remaining.wrappedValue == 5, "initial remaining equals duration")

        controller.start()
        let running = h.render {
            useCountdown(duration: 5, timeInterval: 10)
        }
        #expect(running.isRunning.wrappedValue, "start() must flip the controller to running")

        running.cancel()
        let cancelled = h.render {
            useCountdown(duration: 5, timeInterval: 10)
        }
        #expect(!cancelled.isRunning.wrappedValue, "cancel() must stop the countdown")
        #expect(cancelled.remaining.wrappedValue == 5, "cancel() must reset remaining to the duration")
    }

    @Test("useCountdown pause freezes the countdown")
    func countdownPause() {
        let h = StateTest()

        _ = h.render {
            useCountdown(duration: 9, timeInterval: 10)
        }
        var controller = h.render {
            useCountdown(duration: 9, timeInterval: 10)
        }
        controller.start()
        controller = h.render {
            useCountdown(duration: 9, timeInterval: 10)
        }
        controller.pause()
        let paused = h.render {
            useCountdown(duration: 9, timeInterval: 10)
        }
        #expect(!paused.isRunning.wrappedValue, "pause() must stop the timer without resetting")
    }

    // MARK: useSeenSKStatus

    @Test("useSeenSKStatus reports nil before the status is reached")
    func seenReturnsNilBeforeSeen() {
        let h = StateTest()

        let seen = h.render {
            useSeenSKStatus(.success, in: AsyncPhase<String>.loading)
        }
        #expect(seen == nil, "success not yet seen in a loading phase")
    }

    @Test("useSeenSKStatus reports the status once reached and keeps it")
    func seenLatchesOnceReached() {
        let h = StateTest()

        let first = h.render {
            useSeenSKStatus(.success, in: AsyncPhase<String>.success("v"))
        }
        #expect(first == .success, "reached status must be reported")

        // Later render with a loading phase: the latch must hold.
        let latched = h.render {
            useSeenSKStatus(.success, in: AsyncPhase<String>.loading)
        }
        #expect(latched == .success, "once seen, the status stays reported")
    }
}
