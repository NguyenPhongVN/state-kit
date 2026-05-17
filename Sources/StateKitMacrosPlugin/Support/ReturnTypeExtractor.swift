import SwiftSyntax

enum ReturnTypeExtractor {
    enum ExtractionError: Error, CustomStringConvertible {
        case methodNotFound(String)
        case noReturnType
        case invalidGenericType

        var description: String {
            switch self {
            case .methodNotFound(let name):
                return "Method '\(name)' not found in declaration"
            case .noReturnType:
                return "Method has no return type"
            case .invalidGenericType:
                return "Invalid or unsupported generic type"
            }
        }
    }

    /// Extract return type from a method matching the given name
    static func extract(from decl: DeclGroupSyntax, methodName: String) throws -> TypeSyntax {
        guard let function = findMethod(in: decl, named: methodName) else {
            throw ExtractionError.methodNotFound(methodName)
        }

        guard let returnType = function.signature.returnClause?.type else {
            throw ExtractionError.noReturnType
        }

        return returnType
    }

    /// Extract the Nth generic argument from a type (0-indexed)
    static func extractGenericArg(from type: TypeSyntax, index: Int) throws -> TypeSyntax {
        if let identifierType = type.as(IdentifierTypeSyntax.self),
           let genericArgs = identifierType.genericArgumentClause {
            let args = Array(genericArgs.arguments)
            if index < args.count {
                // Use string representation to ensure we get a valid TypeSyntax
                return TypeSyntax("\(raw: args[index].argument)")
            }
        }
        
        // Fallback for non-generic or index out of bounds
        return type
    }

    /// Extract the underlying type of a typealias named 'named' within a declaration
    static func extractTypealias(from decl: DeclGroupSyntax, named: String) throws -> String {
        for member in decl.memberBlock.members {
            if let typealiasDecl = member.decl.as(TypeAliasDeclSyntax.self),
               typealiasDecl.name.text == named {
                return typealiasDecl.initializer.value.description.trimmingCharacters(in: .whitespaces)
            }
        }
        throw ExtractionError.noReturnType
    }

    /// Find a function declaration by name within a struct/class
    private static func findMethod(in decl: DeclGroupSyntax, named: String) -> FunctionDeclSyntax? {
        for member in decl.memberBlock.members {
            if let function = member.decl.as(FunctionDeclSyntax.self),
               function.name.text == named {
                return function
            }
        }
        return nil
    }

    /// Check if a function is async throwing
    static func isFunctionAsyncThrowing(_ function: FunctionDeclSyntax) -> Bool {
        let hasThrows = function.signature.effectSpecifiers?.throwsClause != nil
        let hasAsync = function.signature.effectSpecifiers?.asyncSpecifier != nil
        return hasThrows && hasAsync
    }

    /// Check if a function is async (non-throwing)
    static func isFunctionAsync(_ function: FunctionDeclSyntax) -> Bool {
        let hasAsync = function.signature.effectSpecifiers?.asyncSpecifier != nil
        let hasThrows = function.signature.effectSpecifiers?.throwsClause != nil
        return hasAsync && !hasThrows
    }
}
