import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct DebounceMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.onlyApplicableToFunctions
        }

        let functionName = funcDecl.name.text
        let debouncedName = functionName + "_debounced"
        
        let modifiers = declaration.asProtocol(WithModifiersSyntax.self)?.modifiers
        let isStatic = modifiers?.contains { $0.name.text == "static" } ?? false
        let staticKeyword = isStatic ? "static " : ""

        // Extract milliseconds argument
        var milliseconds: Int = 0
        if let args = node.arguments?.as(LabeledExprListSyntax.self),
           let firstArg = args.first?.expression.as(IntegerLiteralExprSyntax.self) {
            milliseconds = Int(firstArg.literal.text) ?? 0
        }

        let taskName = "_\(functionName)Task"
        
        let taskDecl: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)private var \(raw: taskName): Task<Void, Never>?
        """

        let debouncedFunc: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)func \(raw: debouncedName)() {
            \(raw: taskName)?.cancel()
            \(raw: taskName) = Task {
                try? await Task.sleep(nanoseconds: UInt64(\(raw: milliseconds)) * 1_000_000)
                if !Task.isCancelled {
                    await \(raw: functionName)()
                }
            }
        }
        """

        return [taskDecl, debouncedFunc]
    }
}
