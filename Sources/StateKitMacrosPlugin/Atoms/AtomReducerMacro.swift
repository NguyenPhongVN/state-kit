import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct AtomReducerMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let className = structDecl.name.text
        
        // Extract State and Action typealiases
        var stateType: String = "Any"
        var actionType: String = "Any"

        for member in structDecl.memberBlock.members {
            if let typealiasDecl = member.decl.as(TypeAliasDeclSyntax.self) {
                if typealiasDecl.name.text == "State" {
                    stateType = typealiasDecl.initializer.value.trimmedDescription
                } else if typealiasDecl.name.text == "Action" {
                    actionType = typealiasDecl.initializer.value.trimmedDescription
                }
            }
        }

        let atomStructName = className + "Atom"
        let atomStruct: DeclSyntax = """
        struct \(raw: atomStructName): SKStateAtom, Hashable {
            typealias Value = \(raw: stateType)
            
            private let reducer = \(raw: className)()
            
            @MainActor
            func defaultValue(context: SKAtomTransactionContext) -> \(raw: stateType) {
                \(raw: stateType)()
            }
            
            @MainActor
            func reduce(_ state: inout \(raw: stateType), action: \(raw: actionType)) {
                reducer.reduce(&state, action: action)
            }
        }
        """

        let sharedDecl: DeclSyntax = """
        @MainActor
        public static let shared = \(raw: atomStructName)()
        """

        return [atomStruct, sharedDecl]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let stateAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): SKStateAtom {}")
        let hashableExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Hashable {}")

        return [stateAtomExtension, hashableExtension]
    }
}
