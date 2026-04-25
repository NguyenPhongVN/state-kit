struct Queue<T> {
    private var elements: [T] = []
    
    mutating func enqueue(_ value: T) {
        elements.append(value)
    }
    
    mutating func dequeue() -> T? {
        if elements.isEmpty { return nil }
        return elements.removeFirst()
    }
    
    func peek() -> T? {
        return elements.first
    }
    
    var isEmpty: Bool {
        return elements.isEmpty
    }
}
