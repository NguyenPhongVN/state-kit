import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct HookMemoMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        guard let computeFn = PropertyExtractor.function(in: structDecl, named: "compute") else {
            throw MacroError.missingComputeMethod
        }

        guard let returnType = computeFn.signature.returnClause?.type else {
            throw MacroError.invalidReturnType
        }

        let properties = PropertyExtractor.storedVars(from: structDecl)
        let structName = structDecl.name.text
        let hookName = "use" + structName + "Memo"

        var paramList: [String] = []
        var depsList: [String] = []
        var instanceInit: [String] = []

        for prop in properties {
            paramList.append("\(prop.name): \(prop.typeName)")
            depsList.append(prop.name)
            instanceInit.append("    \(prop.name): \(prop.name)")
        }

        let params = paramList.joined(separator: ", ")
        let deps = depsList.isEmpty ? ".once" : ".preserved(by: \(depsList.joined(separator: ", ")))"
        let initCode = instanceInit.isEmpty ? "()" : "(\n" + instanceInit.joined(separator: ",\n") + "\n    )"

        let hookFunction: DeclSyntax = """
        @MainActor
        public func \(raw: hookName)(\(raw: params)) -> \(returnType) {
            useMemo(updateStrategy: \(raw: deps)) {
                \(raw: structName)\(raw: initCode).compute()
            }
        }
        """

        return [hookFunction]
    }
}
