import Observation

@Observable
public final class StateSignal<T> {

    public var value: T

    public init(_ value: T) {
        self.value = value
    }
}
