import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// HookPreviousMacro: @attached(peer, names: prefixed(use))
//
// Generates a peer function named "use<StructName>" that tracks the
// previous value of a single property using useRef + useEffect.
//
// ── Example ──────────────────────────────────────────────────────────
//   @HookPrevious struct Score {
//       let score: Int
//   }
//
// Expands to:
//   struct Score { let score: Int }
//
//   @MainActor
//   func useScore(score: Int) -> Int? {
//       let ref = StateKit.useRef(Int?.none)
//       let previous = ref.value
//       StateKit.useEffect(updateStrategy: .preserved(by: score)) {
//           ref.value = score
//           return nil
//       }
//       return previous
//   }
//
// Usage:
//   let prev = useScore(score: 10)  // nil (first render)
//   let prev = useScore(score: 20)  // 10 (previous render)

public struct HookPreviousMacro: PeerMacro {
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
        guard properties.count == 1 else {
            throw MacroError.custom("HookPrevious requires exactly one stored property")
        }

        let prop = properties[0]

        let (accessPrefix, staticKeyword) = AttributeHelper.modifierPrefixes(from: structDecl)

        let hookDecl: DeclSyntax = """
        @MainActor
        \(raw: accessPrefix)\(raw: staticKeyword)func \(raw: funcName)(\(raw: prop.name): \(raw: prop.typeName)) -> \(raw: prop.typeName)? {
            let ref = StateKit.useRef(\(raw: prop.typeName)?.none)
            let previous = ref.value
            StateKit.useEffect(updateStrategy: .preserved(by: \(raw: prop.name))) {
                ref.value = \(raw: prop.name)
                return nil
            }
            return previous
        }
        """

        return [hookDecl]
    }
}
