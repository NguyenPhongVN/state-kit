import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @RiverpodFamily: Generates a family provider from a Notifier/AsyncNotifier subclass
/// with parameterized build method
public struct RiverpodFamilyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroError.onlyApplicableToClasses
        }

        let className = classDecl.name.text
        let lowerCaseClassName = className.prefix(1).lowercased() + className.dropFirst()

        guard PropertyExtractor.function(in: classDecl, named: "build") != nil else {
            throw MacroError.custom("@RiverpodFamily requires a 'build(param)' method")
        }

        let providerDeclaration: DeclSyntax = """
        public let \(raw: lowerCaseClassName)Family = NotifierProvider.family(
            \(raw: className).new,
        )
        """

        return [providerDeclaration]
    }
}
