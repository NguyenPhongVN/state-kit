import SwiftSyntax

struct PropertyInfo {
    let name: String
    let typeName: String
    let defaultValue: String?
}

enum PropertyExtractor {
    static func storedProperties(from decl: DeclGroupSyntax) -> [PropertyInfo] {
        var properties: [PropertyInfo] = []

        for member in decl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
            // Allow both let and var
            let specifier = varDecl.bindingSpecifier.text
            guard specifier == "var" || specifier == "let" else { continue }

            for binding in varDecl.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }

                let name = pattern.identifier.text
                let typeName = binding.typeAnnotation?.type.description.trimmingCharacters(in: .whitespaces) ?? "Unknown"
                let defaultValue = binding.initializer?.value.description

                properties.append(PropertyInfo(
                    name: name,
                    typeName: typeName,
                    defaultValue: defaultValue
                ))
            }
        }

        return properties
    }

    static func typealiases(from decl: DeclGroupSyntax) -> [String: String] {
        var result: [String: String] = [:]

        for member in decl.memberBlock.members {
            guard let typeAlias = member.decl.as(TypeAliasDeclSyntax.self) else { continue }
            let name = typeAlias.name.text
            let type = typeAlias.initializer.value.description
            result[name] = type
        }

        return result
    }

    static func functions(from decl: DeclGroupSyntax) -> [FunctionDeclSyntax] {
        var functions: [FunctionDeclSyntax] = []

        for member in decl.memberBlock.members {
            if let fn = member.decl.as(FunctionDeclSyntax.self) {
                functions.append(fn)
            }
        }

        return functions
    }

    static func function(in decl: DeclGroupSyntax, named: String) -> FunctionDeclSyntax? {
        functions(from: decl).first { $0.name.text == named }
    }

}
