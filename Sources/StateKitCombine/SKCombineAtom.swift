import Foundation
import Combine
import StateKit
import StateKitAtoms

/// A bridge that allows a Combine `Publisher` to act as an `SKTaskAtom`.
///
/// `SKCombineAtom` wraps a publisher and uses its first emitted value to
/// resolve the atom's state. It produces an `AsyncPhase` value.
public struct SKCombineAtom<P: Publisher & Sendable>: SKThrowingTaskAtom, Hashable where P.Output: Sendable {
    public typealias TaskSuccess = P.Output
    
    private let publisher: P
    private let _identifier: String
    
    public init(_ publisher: P, identifier: String) {
        self.publisher = publisher
        self._identifier = identifier
    }
    
    public func task(context: SKAtomTransactionContext) async throws -> P.Output {
        // Bridge Combine to AsyncSequence and take the first value
        guard let value = try await publisher.values.first(where: { @Sendable _ in true }) else {
            throw NSError(domain: "SKCombineAtom", code: 0, userInfo: [NSLocalizedDescriptionKey: "Publisher completed without emitting a value"])
        }
        return value
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_identifier)
    }
    
    public static func == (lhs: SKCombineAtom<P>, rhs: SKCombineAtom<P>) -> Bool {
        lhs._identifier == rhs._identifier
    }
}

public extension Publisher where Self: Sendable, Self.Output: Sendable {
    /// Bridges this publisher into an `SKTaskAtom`.
    ///
    /// - Parameter identifier: A unique identifier for the atom's identity.
    /// - Returns: An `SKCombineAtom` that can be used with `@SKTask`.
    func asAtom(identifier: String) -> SKCombineAtom<Self> {
        SKCombineAtom(self, identifier: identifier)
    }
}
