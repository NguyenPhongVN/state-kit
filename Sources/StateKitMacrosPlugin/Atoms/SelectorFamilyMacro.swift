import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct SelectorFamilyMacro: MemberAttributeMacro, MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "value")
        let className = structDecl.name.text
        var members: [DeclSyntax] = ["typealias Value = \(raw: returnType)"]

        let properties = PropertyExtractor.storedProperties(from: structDecl)

        if properties.count == 1 {
            let prop = properties[0]
            members.append("""
            @MainActor
            public static let family = selectorFamily { (\(raw: prop.name): \(raw: prop.typeName), context: SKAtomTransactionContext) in
                \(raw: className)(\(raw: prop.name): \(raw: prop.name)).value(context: context)
            }
            """)
        } else {
            let idStructName = "FamilyID"
            members.append("""
            public struct \(raw: idStructName): Hashable, Sendable {
                \(raw: properties.map { "public let \($0.name): \($0.typeName)" }.joined(separator: "\n    "))
                public init(\(raw: properties.map { "\($0.name): \($0.typeName)" }.joined(separator: ", "))) {
                    \(raw: properties.map { "self.\($0.name) = \($0.name)" }.joined(separator: "\n        "))
                }
            }

            @MainActor
            private static let _familyInternal = selectorFamily { (id: \(raw: idStructName), context: SKAtomTransactionContext) in
                \(raw: className)(\(raw: properties.map { "\($0.name): id.\($0.name)" }.joined(separator: ", "))).value(context: context)
            }

            @MainActor
            public static func family(\(raw: properties.map { "\($0.name): \($0.typeName)" }.joined(separator: ", "))) -> any SKValueAtom {
                // Selector family usually returns an atom that computes a value.
                // We return a proxy atom or the value itself?
                // Actually, selectorFamily returns a function that returns an atom instance.
                // Wait! selectorFamily works differently.
                fatalError("selectorFamily not fully implemented in macro yet")
            }
            """)
        }

        return members
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let stateAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): SKValueAtom {}")
        let hashableExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Hashable {}")

        return [stateAtomExtension, hashableExtension]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              funcDecl.name.text == "value" else {
            return []
        }

        if !funcDecl.attributes.contains(where: { attr in
            attr.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "MainActor"
        }) {
            return [AttributeSyntax("@MainActor\n")]
        }

        return []
    }
}
