import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct HookEffectMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        guard PropertyExtractor.function(in: structDecl, named: "run") != nil else {
            throw MacroError.missingRunMethod
        }

        let properties = PropertyExtractor.storedVars(from: structDecl)
        let structName = structDecl.name.text
        let hookName = "use" + structName

        var paramList: [String] = []
        var depsList: [String] = []
        var instanceInit: [String] = []

        for prop in properties {
            paramList.append("\(prop.name): \(prop.typeName)")
            depsList.append(prop.name)
            instanceInit.append("    \(prop.name): \(prop.name)")
        }

        let params = paramList.joined(separator: ", ")
        let deps = depsList.isEmpty ? "" : ".preserved(by: \(depsList.joined(separator: ", ")))"
        let initCode = instanceInit.isEmpty ? "()" : "(\n" + instanceInit.joined(separator: ",\n") + "\n    )"

        let hasCleanup = PropertyExtractor.function(in: structDecl, named: "cleanup") != nil
        let cleanupCall = hasCleanup ? "\(structName)\(initCode).cleanup()" : ""

        let hookFunction: DeclSyntax = """
        @MainActor
        public func \(raw: hookName)(\(raw: params)) {
            useEffect(updateStrategy: \(raw: deps)) {
                let task = Task { await \(raw: structName)\(raw: initCode).run() }
                return { \(raw: cleanupCall); task.cancel() }
            }
        }
        """

        return [hookFunction]
    }
}
