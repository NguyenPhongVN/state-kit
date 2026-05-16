import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ProviderFamilyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.onlyApplicableToFunctions
        }

        let funcName = funcDecl.name.text

        // Extract all parameters except first (which should be ref)
        var familyParams: [String] = []
        var familyParamTypes: [(name: String, type: String)] = []

        let params = funcDecl.signature.parameterClause.parameters
        for (index, param) in params.enumerated() {
            if index == 0 && param.firstName.text == "ref" {
                continue  // Skip ref parameter
            }

            let paramName = param.firstName.text
            let paramType = param.type.description.trimmingCharacters(in: .whitespaces)

            familyParams.append(paramName)
            familyParamTypes.append((name: paramName, type: paramType))
        }

        guard !familyParams.isEmpty else {
            throw MacroError.methodNotFound("@ProviderFamily requires at least one parameter (besides ref)")
        }

        // Extract return type
        guard let returnType = funcDecl.signature.returnClause?.type else {
            throw MacroError.invalidReturnType
        }

        let paramList = familyParamTypes.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
        let callParams = familyParams.joined(separator: ", ")

        let providerDecl: DeclSyntax = """
        public let \(raw: funcName) = Provider.family { (ref: ProviderRef, \(raw: paramList)) -> \(returnType) in
            \(raw: funcName)(ref: ref, \(raw: callParams))
        }
        """

        return [providerDecl]
    }
}
