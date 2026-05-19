import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// HookLayoutEffectMacro: @attached(peer, names: prefixed(use))
//
// Generates a peer function named "use<StructName>" that wraps
// `StateKit.useLayoutEffect(...)`.
//
// The annotated struct must provide a `run()` method and may optionally
// provide a `cleanup()` method.
//
// Stored properties on the struct become:
//   1) Parameters of the generated hook function.
//   2) Dependencies for `.preserved(by: ...)` so the layout effect reruns
//      when any property value changes.
//
// ── Example ──────────────────────────────────────────────────────────
//   @HookLayoutEffect
//   struct MeasureLayout {
//       var step: Int = 0
//
//       func run() {
//           print("layout phase for step \(step)")
//       }
//   }
//
// Expands to:
//   struct MeasureLayout { ... }
//
//   @MainActor
//   func useMeasureLayout(step: Int) {
//       StateKit.useLayoutEffect(updateStrategy: .preserved(by: step)) {
//           MeasureLayout(step: step).run()
//           return nil
//       }
//   }
//
// If `cleanup()` exists:
//   - The generated effect returns a cleanup closure that calls it.
//
// Usage:
//   let step = state.wrappedValue.step
//   useMeasureLayout(step: step)
//
// Notes:
//   - `run()` is synchronous by design, matching `useLayoutEffect`.
//   - For async work, use `@HookEffect` or `@AsyncHook` instead.
//   - Macro throws `missingRunMethod` when `run()` is not provided.
public struct HookLayoutEffectMacro: PeerMacro {
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
        let effectBody: DeclSyntax
        if hasCleanup {
            effectBody = """
                {
                    \(raw: className)\(raw: initCode).run()
                    return {
                        \(raw: className)\(raw: initCode).cleanup()
                    }
                }
                """
        } else {
            effectBody = """
                {
                    \(raw: className)\(raw: initCode).run()
                    return nil
                }
                """
        }

        let hookFunction: DeclSyntax = """
        @MainActor
        \(raw: accessPrefix)\(raw: staticKeyword)func \(raw: funcName)(\(raw: params)) {
            StateKit.useLayoutEffect(\(raw: depsArg)) \(effectBody)
        }
        """

        return [hookFunction]
    }
}
