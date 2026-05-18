import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// AsyncHookMacro: @attached(peer, names: prefixed(use))
//
// Generates a peer function named "use<StructName>" that wraps useEffect()
// for an async `run()` method.  Similar to HookEffect but requires the
// `run()` method to be explicitly marked `async`.
//
// Stored properties become parameters + effect dependencies.
//
// ── Example ──────────────────────────────────────────────────────────
//   @AsyncHook struct Uploader {
//       var url: String = "https://example.com"
//       func run() async { /* upload */ }
//   }
//
// Expands to:
//   struct Uploader { var url: String = "https://..."; func run() async { ... } }
//
//   @MainActor
//   func useUploader(url: String = "https://example.com") {
//       StateKit.useEffect(updateStrategy: .preserved(by: url)) {
//           let task = Task {
//               let instance = Uploader(url: url)
//               await instance.run()
//           }
//           return { task.cancel() }
//       }
//   }
//
// Usage:
//   useUploader()                          // default URL
//   useUploader(url: "https://other.com")  // re-runs effect

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

        let className = structDecl.name.text
        let funcName = "use" + className

        let properties = PropertyExtractor.storedProperties(from: structDecl)

        let (accessPrefix, staticKeyword) = AttributeHelper.modifierPrefixes(from: structDecl)

        var paramList: [String] = []
        var depsList: [String] = []
        var instanceInit: [String] = []

        for prop in properties {
            paramList.append("\(prop.name): \(prop.typeName)")
            depsList.append(prop.name)
            instanceInit.append("    \(prop.name): \(prop.name)")
        }

        let params = paramList.joined(separator: ", ")
        let depsArg = depsList.isEmpty ? ".once" : ".preserved(by: \(depsList.joined(separator: ", ")))"
        let initCode = instanceInit.isEmpty ? "()" : "(\n" + instanceInit.joined(separator: ",\n") + "\n    )"

        let hasCleanup = PropertyExtractor.function(in: structDecl, named: "cleanup") != nil
        let cleanupStmt = hasCleanup ? "\(className)\(initCode).cleanup()" : ""

        let hookFunction: DeclSyntax = """
        @MainActor
        \(raw: accessPrefix)\(raw: staticKeyword)func \(raw: funcName)(\(raw: params)) {
            StateKit.useEffect(updateStrategy: \(raw: depsArg)) {
                let task = Task {
                    let instance = \(raw: className)\(raw: initCode)
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
