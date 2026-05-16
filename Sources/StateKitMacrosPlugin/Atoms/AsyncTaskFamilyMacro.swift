import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct AsyncTaskFamilyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        guard PropertyExtractor.function(in: structDecl, named: "task") != nil else {
            throw MacroError.missingTaskMethod
        }

        let properties = PropertyExtractor.storedVars(from: structDecl)
        guard !properties.isEmpty else {
            throw MacroError.invalidAtomFamily("Async task family requires at least one stored property as ID parameter")
        }

        let structName = structDecl.name.text
        let factoryName = structName.prefix(1).lowercased() + structName.dropFirst()

        var paramList: [String] = []
        var structInit: [String] = []

        for prop in properties {
            paramList.append("\(prop.name): \(prop.typeName)")
            structInit.append("    \(prop.name): \(prop.name)")
        }

        let params = paramList.joined(separator: ", ")
        let initCode = structInit.isEmpty ? "()" : "(\n" + structInit.joined(separator: ",\n") + "\n    )"

        let factoryFunction: DeclSyntax = """
        public let \(raw: factoryName) = atomFamily { (\(raw: params)) in
            \(raw: structName)\(raw: initCode)
        }
        """

        return [factoryFunction]
    }
}
