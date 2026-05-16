import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct AtomMacro: MemberMacro {
    enum AtomType {
        case state, value, task, throwingTask, publisher
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: DeclGroupSyntax,
        conformingTo protocols: [IdentifierTypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let atomType = try detectAtomType(in: declaration)

        switch atomType {
        case .state:
            let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "defaultValue")
            return ["typealias Value = \(returnType)"]

        case .value:
            let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "value")
            return ["typealias Value = \(returnType)"]

        case .task, .throwingTask:
            let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "task")
            return ["typealias TaskSuccess = \(returnType)"]

        case .publisher:
            let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "publisher")
            return [
                "typealias PublisherOutput = Never",
                "typealias AtomPublisher = \(returnType)"
            ]
        }
    }

    private static func detectAtomType(in decl: DeclGroupSyntax) throws -> AtomType {
        var has = (defaultValue: false, value: false, task: false, publisher: false)

        for member in decl.memberBlock.members {
            if let fn = member.decl.as(FunctionDeclSyntax.self) {
                switch fn.name.text {
                case "defaultValue": has.defaultValue = true
                case "value": has.value = true
                case "task": has.task = true
                case "publisher": has.publisher = true
                default: break
                }
            }
        }

        let count = [has.defaultValue, has.value, has.task, has.publisher].filter { $0 }.count
        guard count == 1 else { throw MacroError.ambiguousAtomType }

        if has.defaultValue { return .state }
        if has.value { return .value }
        if has.task {
            if let taskFn = findFunction(in: decl, named: "task"),
               ReturnTypeExtractor.isFunctionAsyncThrowing(taskFn) {
                return .throwingTask
            }
            return .task
        }
        if has.publisher { return .publisher }

        throw MacroError.ambiguousAtomType
    }

    private static func findFunction(in decl: DeclGroupSyntax, named: String) -> FunctionDeclSyntax? {
        for member in decl.memberBlock.members {
            if let fn = member.decl.as(FunctionDeclSyntax.self), fn.name.text == named {
                return fn
            }
        }
        return nil
    }
}
