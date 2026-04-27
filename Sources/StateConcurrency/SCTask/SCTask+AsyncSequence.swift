import Foundation

extension AsyncSequence where Element: Sendable, Self: Sendable {
    /// Returns an async sequence that throws an error if an element is not produced within the specified timeout.
    /// - Parameter duration: The maximum duration to wait for an element.
    /// - Returns: A timed async sequence.
    public func timeout(_ duration: SCTaskDuration) -> AsyncThrowingTimeoutSequence<Self> {
        AsyncThrowingTimeoutSequence(self, duration: duration)
    }
    
    /// Returns an async sequence that emits elements only after the specified duration has passed without another emission.
    /// - Parameter duration: The debounce duration.
    /// - Returns: A debounced async sequence.
    public func debounce(for duration: SCTaskDuration) -> AsyncDebounceSequence<Self> {
        AsyncDebounceSequence(self, duration: duration)
    }
}

/// An async sequence that throws a timeout error if an element is not produced within a specified duration.
public struct AsyncThrowingTimeoutSequence<Base: AsyncSequence & Sendable>: AsyncSequence where Base.Element: Sendable {
    public typealias Element = Base.Element
    
    let base: Base
    let duration: SCTaskDuration
    
    init(_ base: Base, duration: SCTaskDuration) {
        self.base = base
        self.duration = duration
    }
    
    public struct Iterator: AsyncIteratorProtocol {
        var streamIterator: AsyncThrowingStream<Element, Error>.AsyncIterator
        
        public mutating func next() async throws -> Base.Element? {
            try await streamIterator.next()
        }
    }
    
    public func makeAsyncIterator() -> Iterator {
        // Capture properties safely for the Task
        let b = base
        let d = duration
        
        let stream = AsyncThrowingStream<Element, Error> { continuation in
            let task = Task {
                do {
                    var currentTimer: Task<Void, Never>?
                    
                    // Start timer for the first element
                    currentTimer = Task {
                        do {
                            try await Task.sleep(duration: d)
                            continuation.finish(throwing: SCTimeoutError(d.asTimeInterval))
                        } catch {
                            // Cancelled, do nothing
                        }
                    }
                    
                    for try await element in b {
                        currentTimer?.cancel()
                        continuation.yield(element)
                        
                        if Task.isCancelled { break }
                        
                        // Start timer for the next element
                        currentTimer = Task {
                            do {
                                try await Task.sleep(duration: d)
                                continuation.finish(throwing: SCTimeoutError(d.asTimeInterval))
                            } catch {
                                // Cancelled, do nothing
                            }
                        }
                    }
                    currentTimer?.cancel()
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
        
        return Iterator(streamIterator: stream.makeAsyncIterator())
    }
}

/// An async sequence that debounces the elements of a base async sequence.
public struct AsyncDebounceSequence<Base: AsyncSequence & Sendable>: AsyncSequence where Base.Element: Sendable {
    public typealias Element = Base.Element
    
    let base: Base
    let duration: SCTaskDuration
    
    init(_ base: Base, duration: SCTaskDuration) {
        self.base = base
        self.duration = duration
    }
    
    public struct Iterator: AsyncIteratorProtocol {
        var streamIterator: AsyncThrowingStream<Element, Error>.AsyncIterator
        
        public mutating func next() async throws -> Base.Element? {
            try await streamIterator.next()
        }
    }
    
    public func makeAsyncIterator() -> Iterator {
        // Capture properties safely for the Task
        let b = base
        let d = duration
        
        let stream = AsyncThrowingStream<Element, Error> { continuation in
            let task = Task {
                do {
                    var currentTimer: Task<Void, Never>?
                    
                    for try await element in b {
                        currentTimer?.cancel()
                        
                        if Task.isCancelled { break }
                        
                        currentTimer = Task {
                            do {
                                try await Task.sleep(duration: d)
                                continuation.yield(element)
                            } catch {
                                // Cancelled, do nothing
                            }
                        }
                    }
                    
                    // Wait for the final pending emission, if any
                    _ = await currentTimer?.value
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
        
        return Iterator(streamIterator: stream.makeAsyncIterator())
    }
}
