struct Stack<T> {
    private var elements: [T] = []
    
    mutating func push(_ value: T) {
        elements.append(value)
    }
    
    mutating func pop() -> T? {
        return elements.popLast()
    }
    
    func peek() -> T? {
        return elements.last
    }
    
    var isEmpty: Bool {
        return elements.isEmpty
    }
}
