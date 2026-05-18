import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// HookCallbackMacro: @attached(peer, names: prefixed(use))
//
// Generates a peer function named "use<StructName>" that wraps useCallback().
// The struct provides a `call` or `handle` method whose parameters and return
// type become the generated closure's signature.
//
// ── Example ──────────────────────────────────────────────────────────
//   @HookCallback struct Greet {
//       func call(_ name: String) -> String { "Hello, \(name)!" }
//   }
//
// Expands to:
//   struct Greet { func call(...) -> String { ... } }
//
//   @MainActor
//   func useGreet() -> (_ name: String) -> String {
//       StateKit.useCallback(updateStrategy: .once) { (_ name: String) in
//           Greet().call(name: name)
//       }
//   }
//
// Usage:
//   let cb = useGreet()
//   cb("World")  // "Hello, World!"

public struct HookCallbackMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let className = structDecl.name.text
        let funcName = "use" + className

        let (accessPrefix, staticKeyword) = AttributeHelper.modifierPrefixes(from: structDecl)

        // Find call or handle method and extract its parameter signature + return type.
        var methodName = "call"
        var paramList = ""
        var argList = ""
        var returnType = "Void"

        func extractParams(from fn: FunctionDeclSyntax) {
            let params = fn.signature.parameterClause.parameters
            paramList = params.map { $0.description.trimmingCharacters(in: .whitespaces) }.joined(separator: ", ")
            argList = params.map { p in
                let firstName = p.firstName.text
                let secondName = p.secondName?.text
                if firstName == "_", let second = secondName {
                    return second
                } else if firstName != "_" {
                    if let second = secondName {
                        return "\(firstName): \(second)"
                    }
                    return firstName
                }
                return firstName
            }.joined(separator: ", ")
            returnType = fn.signature.returnClause?.type.description.trimmingCharacters(in: .whitespaces) ?? "Void"
        }

        if let fn = PropertyExtractor.function(in: structDecl, named: "handle") {
            methodName = "handle"
            extractParams(from: fn)
        } else if let fn = PropertyExtractor.function(in: structDecl, named: "call") {
            methodName = "call"
            extractParams(from: fn)
        }

        let hookDecl: DeclSyntax = """
        @MainActor
        \(raw: accessPrefix)\(raw: staticKeyword)func \(raw: funcName)() -> (\(raw: paramList)) -> \(raw: returnType) {
            StateKit.useCallback(updateStrategy: .once) { (\(raw: paramList)) in
                \(raw: className)().\(raw: methodName)(\(raw: argList))
            }
        }
        """

        return [hookDecl]
    }
}
