import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct AtomMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        var members: [DeclSyntax] = []

        // Detect type from method presence
        if PropertyExtractor.function(in: structDecl, named: "defaultValue") != nil {
            let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "defaultValue")
            members.append("typealias Value = \(returnType)")
        } else if PropertyExtractor.function(in: structDecl, named: "value") != nil {
            let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "value")
            members.append("typealias Value = \(returnType)")
        } else if PropertyExtractor.function(in: structDecl, named: "task") != nil {
            let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "task")
            members.append("typealias TaskSuccess = \(returnType)")
        } else if PropertyExtractor.function(in: structDecl, named: "publisher") != nil {
            let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "publisher")
            let outputType = try ReturnTypeExtractor.extractGenericArg(from: returnType, index: 0)
            members.append("typealias PublisherOutput = \(outputType)")
            members.append("typealias AtomPublisher = \(returnType)")
        }
        
        let sharedDecl: DeclSyntax = "@MainActor public static let shared = \(raw: structDecl.name.text)()"
        members.append(sharedDecl)

        return members
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else { return [] }

        var conformances: [String] = []
        if PropertyExtractor.function(in: structDecl, named: "defaultValue") != nil {
            conformances.append("SKStateAtom")
        } else if PropertyExtractor.function(in: structDecl, named: "value") != nil {
            conformances.append("SKValueAtom")
        } else if PropertyExtractor.function(in: structDecl, named: "task") != nil {
            conformances.append("SKTaskAtom")
        } else if PropertyExtractor.function(in: structDecl, named: "publisher") != nil {
            conformances.append("SKPublisherAtom")
        }

        let ext: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): \(raw: conformances.joined(separator: ", ")) {}")
        let hashableExt: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Hashable {}")

        return [ext, hashableExt]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let funcDecl = member.as(FunctionDeclSyntax.self) else { return [] }
        
        let targetNames = ["defaultValue", "value", "task", "publisher"]
        guard targetNames.contains(funcDecl.name.text) else { return [] }

        if !funcDecl.attributes.contains(where: { attr in
            attr.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "MainActor"
        }) {
            return [AttributeSyntax("@MainActor\n")]
        }

        return []
    }
}
