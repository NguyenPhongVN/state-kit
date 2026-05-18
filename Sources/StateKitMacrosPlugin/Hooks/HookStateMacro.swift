import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// HookStateMacro: @attached(peer, names: prefixed(use))
//
// Generates a peer function named "use<StructName>" that wraps useBinding().
//
// Same design rationale as HookRefMacro — see HookRefMacro.swift for the
// explanation of prefixed(use), access-level propagation, and computed/lazy
// property filtering.
//
// ── Example ──────────────────────────────────────────────────────────
//   @HookState struct Count {
//       var count: Int = 0
//   }
//
// Expands to:
//   struct Count { var count: Int = 0 }
//
//   @MainActor
//   func useCount(count: Int = 0) -> Binding<Count> {
//       return StateKit.useBinding(Count(count: count))
//   }
//
// Usage:
//   let $count = useCount()         // Binding<Count> with default 0
//   $count.count.wrappedValue       // read
//   $count.count.wrappedValue = 5   // write
//
// Unlike HookRef, HookState requires at least one stored property
// because Binding<EmptyStruct> is not useful.

public struct HookStateMacro: PeerMacro {
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

        let properties = PropertyExtractor.storedProperties(from: structDecl)
        guard !properties.isEmpty else {
            throw MacroError.methodNotFound("stored properties for HookState")
        }

        let (accessPrefix, staticKeyword) = AttributeHelper.modifierPrefixes(from: structDecl)

        let params = properties.map { prop in
            if let defaultVal = prop.defaultValue {
                "\(prop.name): \(prop.typeName) = \(defaultVal)"
            } else {
                "\(prop.name): \(prop.typeName)"
            }
        }.joined(separator: ", ")

        let initArgs = properties.map { "\($0.name): \($0.name)" }.joined(separator: ", ")

        let hookDecl: DeclSyntax = """
        @MainActor
        \(raw: accessPrefix)\(raw: staticKeyword)func \(raw: funcName)(\(raw: params)) -> Binding<\(raw: className)> {
            return StateKit.useBinding(\(raw: className)(\(raw: initArgs)))
        }
        """

        return [hookDecl]
    }
}
