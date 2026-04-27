import Foundation
import SwiftUI

private func _normalizedTimeInterval(_ interval: TimeInterval) -> TimeInterval {
    interval > 0 ? interval : 0.0001
}

/// A hook that creates a countdown timer with configurable tick interval and
/// imperative controls.
///
/// The timer is idle until `start()` or `resume()` is called. While running,
/// the hook updates `remaining` on each tick and emits `.running(remaining)`
/// through `phase`. `pause()` pauses the timer at the current remaining
/// value, `resume()` continues from the current remaining value, and
/// `cancel()` resets back to the latest `duration` value.
///
/// Internally the hook stores a `deadline` and recomputes remaining time from
/// `Date()` on every tick, which avoids cumulative drift from subtracting the
/// interval over and over.
///
/// - Parameters:
///   - duration: Initial countdown duration in seconds.
///   - timeInterval: Seconds between timer ticks (default: `0.1`). If
///     less than or equal to zero, `0.0001` is used.
/// - Returns: `CountdownController` with the current remaining-time binding,
///   phase binding, and stable `start` / `pause` / `resume` / `cancel`
///   actions.
///
/// ### Example
/// ```swift
/// struct CountdownView: StateView {
///     var stateBody: some View {
///         let countdown = useCountdown(duration: 60, timeInterval: 1)
///
///         VStack {
///             Text(countdown.remaining.wrappedValue.formatted())
///             Button("Start") { countdown.start() }
///             Button("Pause") { countdown.pause() }
///             Button("Resume") { countdown.resume() }
///             Button("Cancel") { countdown.cancel() }
///         }
///     }
/// }
/// ```
@MainActor
public func useCountdown(
    duration: Double,
    timeInterval: TimeInterval = 0.1
) -> CountdownController {
    let tickInterval = _normalizedTimeInterval(timeInterval)

    @HState var remaining = duration
    @HState var isRunning = false
    @HState var phase = CountdownController.Phase.idle

    @HRef var timer: Timer? = nil
    @HRef var deadline: Date? = nil
    @HRef var latestDuration = duration

    latestDuration = duration

    let invalidateTimer = useCallback(updateStrategy: .once, {
        timer?.invalidate()
        timer = nil
    } as @MainActor () -> Void)

    let tick = useCallback(updateStrategy: .once, {
        guard let endDate = deadline else { return }

        let nextRemaining = max(0, endDate.timeIntervalSinceNow)
        remaining = nextRemaining

        if nextRemaining <= 0 {
            invalidateTimer()
            isRunning = false
            phase = .completed
            deadline = nil
        } else {
            phase = .running(nextRemaining)
        }
    } as @MainActor () -> Void)

    useEffect(updateStrategy: .preserved(by: [AnyHashable(isRunning), AnyHashable(tickInterval)])) {
        guard isRunning else { return nil }

        invalidateTimer()

        let createdTimer = Timer(
            timeInterval: tickInterval,
            repeats: true
        ) { _ in
            Task { @MainActor in
                tick()
            }
        }
        createdTimer.tolerance = min(tickInterval * 0.1, tickInterval)
        RunLoop.main.add(createdTimer, forMode: .common)
        timer = createdTimer

        return {
            createdTimer.invalidate()
            if timer === createdTimer {
                timer = nil
            }
        }
    }

    let start = useCallback(updateStrategy: .once, {
        invalidateTimer()
        let initial = max(0, latestDuration)
        remaining = initial
        if initial <= 0 {
            isRunning = false
            deadline = nil
            phase = .completed
            return
        }
        deadline = Date().addingTimeInterval(initial)
        isRunning = true
        phase = .running(initial)
    } as @MainActor () -> Void)

    let pause = useCallback(updateStrategy: .once, {
        invalidateTimer()
        deadline = nil
        isRunning = false
        phase = .paused
    } as @MainActor () -> Void)

    let resume = useCallback(updateStrategy: .once, {
        let current = max(0, remaining)
        guard current > 0 else {
            phase = .completed
            return
        }
        invalidateTimer()
        deadline = Date().addingTimeInterval(current)
        isRunning = true
        phase = .running(current)
    } as @MainActor () -> Void)

    let cancel = useCallback(updateStrategy: .once, {
        invalidateTimer()
        deadline = nil
        isRunning = false
        remaining = max(0, latestDuration)
        phase = .canceled
    } as @MainActor () -> Void)

    return CountdownController(
        remaining: $remaining,
        isRunning: $isRunning,
        start: start,
        pause: pause,
        resume: resume,
        cancel: cancel,
        phase: $phase
    )
}

public struct CountdownController {
    public let remaining: Binding<Double>
    public let isRunning: Binding<Bool>
    public let start: @MainActor () -> Void
    public let pause: @MainActor () -> Void
    public let resume: @MainActor () -> Void
    public let cancel: @MainActor () -> Void
    public let phase: Binding<Phase>

    public init(
        remaining: Binding<Double>,
        isRunning: Binding<Bool>,
        start: @escaping @MainActor () -> Void,
        pause: @escaping @MainActor () -> Void,
        resume: @escaping @MainActor () -> Void,
        cancel: @escaping @MainActor () -> Void,
        phase: Binding<Phase>
    ) {
        self.remaining = remaining
        self.isRunning = isRunning
        self.start = start
        self.pause = pause
        self.resume = resume
        self.cancel = cancel
        self.phase = phase
    }
}

public extension CountdownController {
    enum Phase: Equatable, Sendable {
        case idle
        case running(Double)
        case paused
        case canceled
        case completed
    }
}

