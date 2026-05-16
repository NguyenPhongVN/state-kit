import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct HookReducerMacro: PeerMacro {
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
        let hookName = "use" + structName

        let hookFunction: DeclSyntax = """
        @MainActor
        public func \(raw: hookName)(initial: \(raw: stateType) = \(raw: stateType)()) -> (\(raw: stateType), (\(raw: actionType)) -> Void) {
            let reducer = \(raw: structName)()
            return useReducer(initial) { state, action in
                reducer.reduce(&state, action: action)
            }
        }
        """

        return [hookFunction]
    }
}
