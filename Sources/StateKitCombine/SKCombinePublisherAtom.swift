import Foundation
import Combine
import StateKit
import StateKitAtoms

/// A bridge that allows a Combine `Publisher` to act as an `SKPublisherAtom`.
///
/// `SKCombinePublisherAtom` wraps a publisher and exposes its lifecycle as
/// reactive atom state (`PublisherPhase`).
public struct SKCombinePublisherAtom<P: Publisher & Sendable>: SKPublisherAtom, Hashable where P.Output: Sendable {
    public typealias PublisherOutput = P.Output
    public typealias AtomPublisher = P
    
    private let _publisher: P
    private let _identifier: String
    
    public init(_ publisher: P, identifier: String) {
        self._publisher = publisher
        self._identifier = identifier
    }
    
    public func publisher(context: SKAtomTransactionContext) -> P {
        _publisher
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_identifier)
    }
    
    public static func == (lhs: SKCombinePublisherAtom<P>, rhs: SKCombinePublisherAtom<P>) -> Bool {
        lhs._identifier == rhs._identifier
    }
}

public extension Publisher where Self: Sendable, Self.Output: Sendable {
    /// Bridges this publisher into an `SKPublisherAtom`.
    ///
    /// Use this for long-running streams that emit multiple values.
    ///
    /// - Parameter identifier: A unique identifier for the atom's identity.
    /// - Returns: An `SKCombinePublisherAtom` that can be used with `@SKValue`.
    func asPublisherAtom(identifier: String) -> SKCombinePublisherAtom<Self> {
        SKCombinePublisherAtom(self, identifier: identifier)
    }
}
