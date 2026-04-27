import Foundation

/// A property-wrapper form of `useCountdown(duration:timeInterval:)`.
///
/// `HCountdown` exposes the countdown's remaining time as the wrapped value
/// and the full `CountdownController` as the projected value.
///
/// This makes the call site read naturally:
/// ```swift
/// @HCountdown(timeInterval: 1) var countdown = 60
/// ```
///
/// where:
/// - `countdown` is the current remaining time
/// - `$countdown` is the controller used to start, pause, resume, or cancel
///
/// Like other hook property wrappers in this package, `HCountdown` must be
/// used inside `StateScope` or `StateView.stateBody`.
///
/// ### Example
/// ```swift
/// struct CountdownView: StateView {
///     @HCountdown(timeInterval: 1) var countdown = 10
///
///     var stateBody: some View {
///         VStack {
///             Text("\(Int(countdown))")
///
///             Button("Start") {
///                 $countdown.start()
///             }
///
///             Button("Pause") {
///                 $countdown.pause()
///             }
///         }
///     }
/// }
/// ```
@propertyWrapper
@MainActor
public struct HCountdown {
    private let countdownController: CountdownController

    /// Creates a countdown wrapper with the given initial duration and tick interval.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial countdown duration in seconds.
    ///   - timeInterval: Seconds between countdown ticks.
    public init(
        wrappedValue duration: Double,
        timeInterval: Double
    ) {
        self.countdownController = useCountdown(
            duration: duration,
            timeInterval: timeInterval
        )
    }

    /// The current remaining countdown time.
    public var wrappedValue: Double {
        countdownController.remaining.wrappedValue
    }

    /// The underlying `CountdownController`.
    ///
    /// Use the projected value to control the countdown lifecycle:
    /// `start()`, `pause()`, `resume()`, and `cancel()`.
    public var projectedValue: CountdownController {
        countdownController
    }
}
