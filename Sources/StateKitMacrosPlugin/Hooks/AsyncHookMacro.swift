import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @AsyncHook: Generates an async hook function from a struct with async run() method
/// Handles dependency tracking and provides async/await syntax without explicit Task wrapping
public struct AsyncHookMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        guard let runMethod = PropertyExtractor.function(in: structDecl, named: "run") else {
            throw MacroError.missingRunMethod
        }

        guard ReturnTypeExtractor.isFunctionAsync(runMethod) else {
            throw MacroError.custom("@AsyncHook requires a 'run()' method marked with 'async'")
        }

        let properties = PropertyExtractor.storedProperties(from: structDecl)
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
        let cleanupStmt = hasCleanup ? "\(structName)\(initCode).cleanup()" : ""

        let hookFunction: DeclSyntax = """
        @MainActor
        public func \(raw: hookName)(\(raw: params)) {
            useEffect(updateStrategy: \(raw: deps)) {
                let task = Task {
                    let instance = \(raw: structName)\(raw: initCode)
                    await instance.run()
                }
                return {
                    task.cancel()
                    \(raw: cleanupStmt)
                }
            }
        }
        """

        return [hookFunction]
    }
}
