import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @PublisherAtom: Declares a Combine publisher-based atom for reactive streams.
///
/// Generates a `SKPublisherAtom` conformance extension with `PublisherOutput` and
/// `AtomPublisher` typealiases inferred from the return type of `publisher(context:)`.
/// Also synthesizes `Hashable`.
///
/// ## Generated Conformances
/// - `SKPublisherAtom` with `PublisherOutput` + `AtomPublisher` typealiases
/// - `Hashable`
///
/// ## User Requirements
/// - A method `func publisher(context: SKAtomTransactionContext) -> P` where `P` is a Combine publisher
///   (e.g., `AnyPublisher<Int, Error>`). The output type is extracted as the first generic argument.
///
/// ## Behavior
/// - Access level propagates from the struct to the generated typealiases.
/// - `@MainActor` is automatically added to `publisher(context:)` unless the struct or method already has it.
public struct PublisherAtomMacro: ExtensionMacro, MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Extract the return type from publisher(context:) to determine PublisherOutput and AtomPublisher
        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "publisher")
        // PublisherOutput is the first generic argument of the publisher type
        let outputType = try ReturnTypeExtractor.extractGenericArg(from: returnType, index: 0)
        // Propagate the struct's access level to the generated typealiases
        let accessPrefix = AttributeHelper.accessLevel(from: declaration)

        // Only add @MainActor prefix if the struct itself doesn't already have it
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: declaration) ? "" : "@MainActor "

        // Generate: extension MyAtom: SKPublisherAtom { typealias PublisherOutput = O; typealias AtomPublisher = P }
        let publisherAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("""
        \(raw: mainActorAttr)extension \(type.trimmed): SKPublisherAtom {
            \(raw: accessPrefix)typealias PublisherOutput = \(raw: outputType.trimmedDescription)
            \(raw: accessPrefix)typealias AtomPublisher = \(raw: returnType.trimmedDescription)
        }
        """)
        
        // Generate: extension MyAtom: Hashable {}
        let hashableExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Hashable {}")

        return [publisherAtomExtension, hashableExtension]
    }

    // MemberAttributeMacro: adds @MainActor to publisher(context:) if needed
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // Only apply to the publisher(context:) method
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              funcDecl.name.text == "publisher" else {
            return []
        }

        // Skip if the struct already has @MainActor
        if AttributeHelper.hasAttribute("MainActor", on: declaration) {
            return []
        }

        // Add @MainActor if the method doesn't already have it
        if !AttributeHelper.hasAttribute("MainActor", on: funcDecl) {
            return [AttributeHelper.mainActorNewline]
        }

        return []
    }
}
