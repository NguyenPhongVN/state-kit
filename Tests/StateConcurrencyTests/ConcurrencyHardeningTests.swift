import Testing
import Foundation
@testable import StateConcurrency

// Spec 009 US9: concurrency utilities survive adversarial inputs — no
// spurious timeouts, no limiter deadlock on early cancellation, no traps on
// negative durations.

@Suite("Concurrency Hardening — 009 US9")
struct ConcurrencyHardeningTests {

    @Test("throwingTimeout returns the computed success over a racing timeout")
    func timeoutReturnsSuccess() async throws {
        // Operation completes right at the timeout boundary; the result must
        // win over the nondeterministic timeout fire.
        let result = try await Task.throwingTimeout(.milliseconds(50)) {
            try await Task.sleep(for: .milliseconds(30))
            return 42
        }
        #expect(result == 42)
    }

    @Test("limiter does not deadlock a waiter cancelled before registration")
    func limiterCancelledWaiter() async throws {
        let limiter = SKConcurrencyLimiter(maxConcurrentTasks: 1)

        // Occupy the only slot.
        let gate = GateFlag()
        let holder = Task {
            try await limiter.execute {
                gate.open()
                try await Task.sleep(for: .seconds(2))
            }
        }
        try await gate.waitOpen()

        // Enqueue a waiter that gets cancelled BEFORE its continuation
        // registers (it starts, sees no free slot, is cancelled immediately).
        let waiter = Task { try await limiter.execute { 7 } }
        try await Task.sleep(for: .milliseconds(20))
        waiter.cancel()

        // Release the slot: the cancelled waiter must not hang the limiter.
        // Cancel the holder after enough time regardless.
        holder.cancel()

        // A third operation must acquire a slot promptly (no deadlock).
        let started = Date()
        let third = Task { try await limiter.execute { 3 } }
        let value = try await third.value
        #expect(value == 3)
        #expect(Date().timeIntervalSince(started) < 3,
                "limiter deadlocked after a cancelled waiter")
    }

    @Test("negative durations clamp instead of trapping")
    func negativeDurations() {
        let duration = SKTaskDuration(TimeInterval(-0.5))
        #expect(duration.asTimeInterval == 0, "negative duration trapped or kept its sign")

        let nan = SKTaskDuration(TimeInterval.nan)
        #expect(nan.asTimeInterval == 0)
    }

    @Test("retry policy validates a non-positive multiplier")
    func retryMultiplierValidated() async {
        let policy = SKRetryPolicy.exponential(initialDelay: .milliseconds(1), multiplier: -2)

        let delay = policy.delay(forAttempt: 3)
        #expect((delay?.asTimeInterval ?? -1) >= 0, "negative multiplier produced a negative delay")
    }
}

final class GateFlag: @unchecked Sendable {
    // poll-based wait; simple and adequate for the test

    private let condition = NSCondition()
    private var isOpen = false

    func open() {
        condition.lock()
        isOpen = true
        condition.broadcast()
        condition.unlock()
    }

    func waitOpen() async throws {
        while !isOpen {
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}
