public final class StateContext {

    public var states: [Any] = []
    public var context: [Any] = []
    public private(set) var index: Int = 0
    
    public init(states: [Any] = [], index: Int = 0) {
        self.states = states
        self.index = index
    }

    public func nextIndex() -> Int {
        defer { index += 1 }
        return index
    }

    public func reset() {
        index = 0
    }
}
