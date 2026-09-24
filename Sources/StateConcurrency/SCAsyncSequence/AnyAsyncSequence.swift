import Foundation

/// A type erased `AsyncSequence`
///
/// This type allows you to create APIs that return an `AsyncSequence` that allows consumers to iterate over the sequence, without exposing the sequence's underlyin type.
/// Typically, you wouldn't actually initialize this type yourself, but instead create one using the `.eraseToAnyAsyncSequence()` operator also provided with this package.
public struct AnyAsyncSequence<Element>: AsyncSequence {
    
    // MARK: - Initializers
    
    /// Create an `AnyAsyncSequence` from an `AsyncSequence` conforming type
    /// - Parameter sequence: The `AnySequence` type you wish to erase
    public init<T: AsyncSequence>(_ sequence: T) where T.Element == Element {
        makeAsyncIteratorClosure = { AnyAsyncIterator(sequence.makeAsyncIterator()) }
    }
    
/// Type-erased async iterator that boxes any concrete iterator.
    public struct AnyAsyncIterator: AsyncIteratorProtocol {
        private let nextClosure: () async throws -> Element?
        
    /// Boxes `iterator` behind the type-erased interface.
        public init<T: AsyncIteratorProtocol>(_ iterator: T) where T.Element == Element {
            var iterator = iterator
            nextClosure = { try await iterator.next() }
        }
        
    /// Forwards to the boxed iterator.
        public func next() async throws -> Element? {
            try await nextClosure()
        }
    }
    
    // MARK: - AsyncSequence
    
    /// The erased element type.
    public typealias Element = Element
    
    /// The boxed iterator type.
    public typealias AsyncIterator = AnyAsyncIterator
    
    /// Forwards to the boxed iterator.
    public func makeAsyncIterator() -> AsyncIterator {
        AnyAsyncIterator(makeAsyncIteratorClosure())
    }
    
    private let makeAsyncIteratorClosure: () -> AsyncIterator
    
}

public extension AsyncSequence {
    
    /// Create a type erased version of this sequence
    /// - Returns: The sequence, wrapped in an `AnyAsyncSequence`
    func eraseToAnyAsyncSequence() -> AnyAsyncSequence<Element> {
        AnyAsyncSequence(self)
    }
}
