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
        let depsArg = depsList.isEmpty ? "" : "updateStrategy: .preserved(by: \(depsList.joined(separator: ", ")))"
        let initCode = instanceInit.isEmpty ? "()" : "(\n" + instanceInit.joined(separator: ",\n") + "\n    )"

        let hasCleanup = PropertyExtractor.function(in: structDecl, named: "cleanup") != nil
        let body: DeclSyntax
        if hasCleanup {
            body = """
                {
                    let task = Task { await \(raw: structName)\(raw: initCode).run() }
                    return {
                        \(raw: structName)\(raw: initCode).cleanup()
                        task.cancel()
                    }
                }
                """
        } else {
            body = """
                {
                    let task = Task { await \(raw: structName)\(raw: initCode).run() }
                    return { task.cancel() }
                }
                """
        }

        let isStatic = structDecl.modifiers.contains(where: { $0.name.text == "static" })
        let staticModifier = isStatic ? "static " : ""

        let hookFunction: DeclSyntax = """
        @MainActor
        \(raw: staticModifier)func \(raw: hookName)(\(raw: params)) {
            useEffect(\(raw: depsArg)) \(body)
        }
        """

        return [hookFunction]
    }
}
