import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// HookEffectMacro: @attached(peer, names: prefixed(use))
//
// Generates a peer function named "use<StructName>" that wraps useEffect().
// The struct must provide an async `run()` method and may optionally provide
// a `cleanup()` method.
//
// Stored properties on the struct become both parameters AND effect
// dependencies (preserved(by: ...)), so the effect re-runs when any of
// them change.
//
// ── Example ──────────────────────────────────────────────────────────
//   @HookEffect struct Logger {
//       var message: String = "loaded"
//       func run() async { print(message) }
//   }
//
// Expands to:
//   struct Logger { var message: String = "loaded"; func run() async { ... } }
//
//   @MainActor
//   func useLogger(message: String = "loaded") {
//       StateKit.useEffect(updateStrategy: .preserved(by: message)) {
//           let task = Task { await Logger(message: message).run() }
//           return { task.cancel() }
//       }
//   }
//
// Usage:
//   useLogger()                    // prints "loaded"
//   useLogger(message: "hello")    // re-runs, prints "hello"

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
        let depsArg = depsList.isEmpty ? "" : "updateStrategy: .preserved(by: \(depsList.joined(separator: ", ")))"
        let initCode = instanceInit.isEmpty ? "()" : "(\n" + instanceInit.joined(separator: ",\n") + "\n    )"

        let hasCleanup = PropertyExtractor.function(in: structDecl, named: "cleanup") != nil
        let body: DeclSyntax
        if hasCleanup {
            body = """
                {
                    let task = Task { await \(raw: className)\(raw: initCode).run() }
                    return {
                        \(raw: className)\(raw: initCode).cleanup()
                        task.cancel()
                    }
                }
                """
        } else {
            body = """
                {
                    let task = Task { await \(raw: className)\(raw: initCode).run() }
                    return { task.cancel() }
                }
                """
        }

        let hookFunction: DeclSyntax = """
        @MainActor
        \(raw: accessPrefix)\(raw: staticKeyword)func \(raw: funcName)(\(raw: params)) {
            StateKit.useEffect(\(raw: depsArg)) \(body)
        }
        """

        return [hookFunction]
    }
}
