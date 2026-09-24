import Foundation
import Combine
import StateKit
import StateKitAtoms

/// A bridge that allows a Combine `Publisher` to act as an `SKPublisherAtom`.
///
/// `SKCombinePublisherAtom` wraps a publisher and exposes its lifecycle as
/// reactive atom state (`PublisherPhase`).
// MARK: - SKCombinePublisherAtom
public struct SKCombinePublisherAtom<P: Publisher & Sendable>: SKPublisherAtom, Hashable where P.Output: Sendable {
    /// The publisher's output type.
    public typealias PublisherOutput = P.Output
    /// The bridged publisher type.
    public typealias AtomPublisher = P
    
    private let _publisher: P
    private let _identifier: String
    
    /// - Parameters:
    ///   - publisher: The Combine publisher to expose.
    ///   - identifier: Stable identity distinguishing this atom in the store.
    public init(_ publisher: P, identifier: String) {
        self._publisher = publisher
        self._identifier = identifier
    }
    
    /// Returns the bridged publisher; the store subscribes on first access.
    public func publisher(context: SKAtomTransactionContext) -> P {
        _publisher
    }
    
    /// Hashes on the stable identifier, not the publisher reference.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_identifier)
    }
    
    public static func == (lhs: SKCombinePublisherAtom<P>, rhs: SKCombinePublisherAtom<P>) -> Bool {
        lhs._identifier == rhs._identifier
    }
}

// MARK: - Publisher
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
