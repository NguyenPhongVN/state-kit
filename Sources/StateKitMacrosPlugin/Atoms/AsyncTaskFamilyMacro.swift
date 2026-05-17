import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct AsyncTaskFamilyMacro: MemberAttributeMacro, MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "task")
        let className = structDecl.name.text
        var members: [DeclSyntax] = ["typealias TaskSuccess = \(raw: returnType)"]

        let properties = PropertyExtractor.storedProperties(from: structDecl)

        if properties.count == 1 {
            let prop = properties[0]
            members.append("""
            @MainActor
            public static let family = atomFamily { (\(raw: prop.name): \(raw: prop.typeName)) in
                \(raw: className)(\(raw: prop.name): \(raw: prop.name))
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
            private static let _familyInternal = atomFamily { (id: \(raw: idStructName)) in
                \(raw: className)(\(raw: properties.map { "\($0.name): id.\($0.name)" }.joined(separator: ", ")))
            }

            @MainActor
            public static func family(\(raw: properties.map { "\($0.name): \($0.typeName)" }.joined(separator: ", "))) -> \(raw: className) {
                _familyInternal(\(raw: idStructName)(\(raw: properties.map { "\($0.name): \($0.name)" }.joined(separator: ", "))))
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
        let stateAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): SKTaskAtom {}")
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
              funcDecl.name.text == "task" else {
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
