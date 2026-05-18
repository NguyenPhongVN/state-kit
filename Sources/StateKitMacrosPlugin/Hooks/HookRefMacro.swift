import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// HookRefMacro: @attached(peer, names: prefixed(use))
//
// Generates a peer function named "use<StructName>" that wraps useRef().
//
// Because @attached(peer, names: arbitrary) is prohibited at global scope
// (SE-0389 / SE-0397), we use names: prefixed(use) which tells the compiler
// every generated name starts with "use".  This IS allowed at file scope.
//
// ── Example ──────────────────────────────────────────────────────────
//   @HookRef struct Counter {
//       var value: Int = 0
//   }
//
// Expands to:
//   struct Counter { var value: Int = 0 }
//
//   @MainActor
//   func useCounter(value: Int = 0) -> StateKit.StateRef<Counter> {
//       return StateKit.useRef(Counter(value: value))
//   }
//
// Usage:
//   let ref = useCounter()          // default 0
//   let ref = useCounter(value: 42) // explicit initial
//   ref.value = 100                 // mutate (StateRef is a class)
//
// ── Access control ───────────────────────────────────────────────────
// The generated function inherits the struct's access level so that
// returning StateRef<PrivateStruct> does not trigger a compiler error
// ("declaration cannot be more visible than its return type").
//
// ── Computed & lazy properties ───────────────────────────────────────
// Computed properties (no initialiser, has accessor block) and lazy
// properties (excluded from Swift's memberwise init) are skipped.
//
// ── Avoiding recursive calls ─────────────────────────────────────────
// The body calls StateKit.useRef(…) instead of bare useRef(…).  If the
// struct were named "Ref" the generated function would be useRef(…),
// shadowing the framework function.  The explicit module prefix prevents
// infinite recursion.

public struct HookRefMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // ── 1. Validate we're on a struct ────────────────────────────
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let className = structDecl.name.text                // e.g. "Counter"
        let funcName = "use" + className                     // e.g. "useCounter"

        // Stored (non-computed, non-lazy) properties only.
        let properties = PropertyExtractor.storedProperties(from: structDecl)

        // ── 2. Access-level propagation ─────────────────────────────
        // Read the struct's access modifier and apply it to the peer
        // function.  Swift forbids returning a less-visible type from a
        // more-visible function.
        let (accessPrefix, staticKeyword) = AttributeHelper.modifierPrefixes(from: structDecl)

        // ── 3. Generate the peer function ───────────────────────────
        //
        // Two code paths:
        //   a) No stored properties → useRef(StructName())
        //   b) One or more stored properties → parameters + init

        if properties.isEmpty {
            // Case (a): Zero stored properties
            //   func useCounter() -> StateKit.StateRef<Counter> {
            //       return StateKit.useRef(Counter())
            //   }
            let hookDecl: DeclSyntax = """
            @MainActor
            \(raw: accessPrefix)\(raw: staticKeyword)func \(raw: funcName)() -> StateKit.StateRef<\(raw: className)> {
                return StateKit.useRef(\(raw: className)())
            }
            """
            return [hookDecl]
        }

        // Case (b): One or more stored properties
        //
        // Build parameter list from stored properties.  Properties with
        // default values become optional parameters; those without become
        // required parameters.
        //
        // Example:
        //   var value: Int = 0, var name: String
        //     → value: Int = 0, name: String
        let params = properties.map { prop in
            if let defaultVal = prop.defaultValue {
                "\(prop.name): \(prop.typeName) = \(defaultVal)"
            } else {
                "\(prop.name): \(prop.typeName)"
            }
        }.joined(separator: ", ")

        // Arguments for the struct's memberwise init.  Both label and
        // value use the same name (e.g. value: value), which is valid
        // Swift and keeps the API clean.
        //
        // Example:  Counter(value: value, name: name)
        let initArgs = properties.map { "\($0.name): \($0.name)" }.joined(separator: ", ")

        let hookDecl: DeclSyntax = """
        @MainActor
        \(raw: accessPrefix)\(raw: staticKeyword)func \(raw: funcName)(\(raw: params)) -> StateKit.StateRef<\(raw: className)> {
            return StateKit.useRef(\(raw: className)(\(raw: initArgs)))
        }
        """

        return [hookDecl]
    }
}
