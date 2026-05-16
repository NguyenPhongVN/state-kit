import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct AtomReducerMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let typealiases = PropertyExtractor.typealiases(from: structDecl)
        guard let stateType = typealiases["State"], let actionType = typealiases["Action"] else {
            throw MacroError.methodNotFound("typealias State and typealias Action")
        }

        guard PropertyExtractor.function(in: structDecl, named: "reduce") != nil else {
            throw MacroError.missingReduceMethod
        }

        let structName = structDecl.name.text
        let atomName = structName + "Atom"
        let initName = structName.prefix(1).lowercased() + structName.dropFirst() + "Atom"

        let atomStruct: DeclSyntax = """
        struct \(raw: atomName): SKStateAtom, Hashable {
            typealias Value = \(raw: stateType)

            private let reducer = \(raw: structName)()

            func defaultValue(context: SKAtomTransactionContext) -> \(raw: stateType) {
                \(raw: stateType)()
            }

            @MainActor
            func reduce(_ state: inout \(raw: stateType), action: \(raw: actionType)) {
                reducer.reduce(&state, action: action)
            }
        }

        public let \(raw: initName) = \(raw: atomName)()
        """

        return [atomStruct]
    }
}
