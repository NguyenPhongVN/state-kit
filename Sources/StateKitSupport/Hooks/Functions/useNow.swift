import Foundation
import StateKit

private func _normalizedNowTimeInterval(_ interval: TimeInterval) -> TimeInterval {
    interval > 0 ? interval : 0.0001
}

/// Returns the current date and keeps it updated on a repeating timer.
///
/// `useNow(every:)` is useful when the UI needs a live time anchor rather than
/// a one-off `Date()` snapshot, for example:
/// - clocks and countdown labels
/// - "last updated" / relative-time text
/// - session timeout warnings
/// - dashboards that should refresh time-dependent formatting every minute
///
/// The hook starts a timer the first time the enclosing `StateScope` appears
/// and invalidates that timer automatically when the scope disappears.
///
/// - Parameter interval: Seconds between updates. Defaults to `1`. If less
///   than or equal to zero, `0.0001` is used.
/// - Returns: A `Date` value that updates on the given interval.
///
/// ### Example
/// ```swift
/// struct RelativeTimeView: StateView {
///     let createdAt: Date
///
///     var stateBody: some View {
///         let now = useNow(every: 60)
///
///         Text(createdAt.formatted(.relative(presentation: .named, unitsStyle: .wide, locale: .current, relativeTo: now)))
///     }
/// }
/// ```
@MainActor
public func useNow(
    every interval: TimeInterval = 1
) -> Date {
    let updateInterval = _normalizedNowTimeInterval(interval)
    let sleepDuration = Duration.seconds(updateInterval)

    @HState var now = Date()
    @HRef var clock = ContinuousClock()
    
    useEffect(updateStrategy: .preserved(by: updateInterval)) {
        let task = Task {
            while !Task.isCancelled {
                try? await clock.sleep(for: sleepDuration)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    now = Date()
                }
            }
        }

        return {
            task.cancel()
        }
    }

    return now
}
