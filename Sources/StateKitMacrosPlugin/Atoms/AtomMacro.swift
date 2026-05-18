import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @Atom: Unified atom macro that auto-detects the atom type at compile time.
///
/// Inspects the struct's methods and automatically selects the correct atom protocol
/// and associated typealiases. Eliminates the need to pick a specific atom macro —
/// just write the method and the macro handles the rest.
///
/// ## Detection rules (first match wins)
/// 1. `defaultValue(context:)` → `SKStateAtom` with `Value` typealias
/// 2. `value(context:)` → `SKValueAtom` with `Value` typealias
/// 3. `task(context:)` → `SKTaskAtom` with `TaskSuccess` typealias
/// 4. `publisher(context:)` → `SKPublisherAtom` with `PublisherOutput` + `AtomPublisher` typealiases
///
/// ## Generated Conformances
/// - One of `{SKStateAtom, SKValueAtom, SKTaskAtom, SKPublisherAtom}` with appropriate typealias
/// - `Hashable`
///
/// ## User Requirements
/// - Exactly one of the recognized methods: `defaultValue(context:)`, `value(context:)`, `task(context:)`, or `publisher(context:)`.
///
/// ## Behavior
/// - Access level propagates from the struct to the generated typealias(es).
/// - `@MainActor` is automatically added to the detected method unless already present.
public struct AtomMacro: ExtensionMacro, MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else { return [] }

        let accessPrefix = AttributeHelper.accessLevel(from: declaration)

        var conformances: [String] = []
        var typealiases: [String] = []

        if PropertyExtractor.function(in: structDecl, named: "defaultValue") != nil {
            conformances.append("SKStateAtom")
            let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "defaultValue")
            typealiases.append("\(accessPrefix)typealias Value = \(returnType.trimmedDescription)")
        } else if PropertyExtractor.function(in: structDecl, named: "value") != nil {
            conformances.append("SKValueAtom")
            let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "value")
            typealiases.append("\(accessPrefix)typealias Value = \(returnType.trimmedDescription)")
        } else if PropertyExtractor.function(in: structDecl, named: "task") != nil {
            conformances.append("SKTaskAtom")
            let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "task")
            typealiases.append("\(accessPrefix)typealias TaskSuccess = \(returnType.trimmedDescription)")
        } else if PropertyExtractor.function(in: structDecl, named: "publisher") != nil {
            conformances.append("SKPublisherAtom")
            let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "publisher")
            let outputType = try ReturnTypeExtractor.extractGenericArg(from: returnType, index: 0)
            typealiases.append("\(accessPrefix)typealias PublisherOutput = \(outputType.trimmedDescription)")
            typealiases.append("\(accessPrefix)typealias AtomPublisher = \(returnType.trimmedDescription)")
        }

        let protocolList = conformances.joined(separator: ", ")
        let typealiasList = typealiases.joined(separator: "\n    ")

        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: declaration) ? "" : "@MainActor "

        let ext: ExtensionDeclSyntax = try ExtensionDeclSyntax("""
        \(raw: mainActorAttr)extension \(type.trimmed): \(raw: protocolList) {
            \(raw: typealiasList)
        }
        """)
        
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

        if AttributeHelper.hasAttribute("MainActor", on: declaration) {
            return []
        }

        if !AttributeHelper.hasAttribute("MainActor", on: funcDecl) {
            return [AttributeHelper.mainActorNewline]
        }

        return []
    }
}
