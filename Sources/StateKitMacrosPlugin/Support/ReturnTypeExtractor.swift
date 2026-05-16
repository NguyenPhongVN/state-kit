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
    /// For now, just returns the full type for PublisherAtom
    /// since extracting from generic types is complex in Swift 6
    static func extractGenericArg(from type: TypeSyntax, index: Int) throws -> TypeSyntax {
        // For AnyPublisher<Output, Failure>, we would want Output
        // But generic argument extraction is complex, so just return the type
        // User can manually specify if needed
        return type
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
