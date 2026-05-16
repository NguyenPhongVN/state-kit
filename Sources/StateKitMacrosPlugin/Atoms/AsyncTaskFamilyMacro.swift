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

        let properties = PropertyExtractor.storedProperties(from: structDecl)
        guard !properties.isEmpty else {
            throw MacroError.invalidAtomFamily("Async task family requires at least one stored property as ID parameter")
        }

        let structName = structDecl.name.text
        let factoryName = structName.prefix(1).lowercased() + structName.dropFirst()

        if properties.count == 1 {
            let prop = properties[0]
            return ["""
            public let \(raw: factoryName) = atomFamily { (\(raw: prop.name): \(raw: prop.typeName)) in
                \(raw: structName)(\(raw: prop.name): \(raw: prop.name))
            }
            """]
        } else {
            let idStructName = structName + "ID"
            let idStruct: DeclSyntax = """
            public struct \(raw: idStructName): Hashable, Sendable {
                \(raw: properties.map { "public let \($0.name): \($0.typeName)" }.joined(separator: "\n    "))
                public init(\(raw: properties.map { "\($0.name): \($0.typeName)" }.joined(separator: ", "))) {
                    \(raw: properties.map { "self.\($0.name) = \($0.name)" }.joined(separator: "\n        "))
                }
            }
            """
            
            let internalFactoryName = "_" + factoryName + "Family"
            let internalFactory: DeclSyntax = """
            private let \(raw: internalFactoryName) = atomFamily { (id: \(raw: idStructName)) in
                \(raw: structName)(\(raw: properties.map { "\($0.name): id.\($0.name)" }.joined(separator: ", ")))
            }
            """
            
            let wrapperFunction: DeclSyntax = """
            public func \(raw: factoryName)(\(raw: properties.map { "\($0.name): \($0.typeName)" }.joined(separator: ", "))) -> some SKTaskAtom {
                \(raw: internalFactoryName)(\(raw: idStructName)(\(raw: properties.map { "\($0.name): \($0.name)" }.joined(separator: ", "))))
            }
            """
            
            return [idStruct, internalFactory, wrapperFunction]
        }
    }
}
