import Foundation
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

public struct AtomMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              let initializer = binding.initializer?.value else {
            return []
        }
        
        let type: String
        if let typeAnnotation = binding.typeAnnotation {
            type = typeAnnotation.type.description.trimmingCharacters(in: .whitespaces)
        } else {
            // Infer simple types from literals
            if initializer.is(IntegerLiteralExprSyntax.self) {
                type = "Int"
            } else if initializer.is(StringLiteralExprSyntax.self) {
                type = "String"
            } else if initializer.is(BooleanLiteralExprSyntax.self) {
                type = "Bool"
            } else if initializer.is(FloatLiteralExprSyntax.self) {
                type = "Double"
            } else {
                // Fallback or throw error? For now, we need an explicit type for complex initializers.
                return []
            }
        }
        
        let modifiers = varDecl.modifiers.description.trimmingCharacters(in: .whitespaces)
        let accessLevel = modifiers.isEmpty ? "" : modifiers + " "
        let structName = "_\(name.prefix(1).uppercased())\(name.dropFirst())Atom"
        
        return [
            """
            \(raw: accessLevel)struct \(raw: structName): SKStateAtom, Hashable {
                public typealias Value = \(raw: type)
                public func defaultValue(context: SKAtomTransactionContext) -> \(raw: type)  {
                    \(raw: initializer)
                }
            }
            """,
            "\(raw: accessLevel)let \(raw: name)Atom = \(raw: structName)()"
        ]
    }
}
