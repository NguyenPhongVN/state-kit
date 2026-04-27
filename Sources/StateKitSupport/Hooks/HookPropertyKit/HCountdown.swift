import Foundation

@propertyWrapper
@MainActor
public struct HCountdown {
    private let countdownController: CountdownController

    public init(
        wrappedValue duration: Double,
        timeInterval: Double
    ) {
        self.countdownController = useCountdown(
            duration: duration,
            timeInterval: timeInterval
        )
    }

    public var wrappedValue: Double {
        countdownController.remaining.wrappedValue
    }

    public var projectedValue: CountdownController {
        countdownController
    }
}
