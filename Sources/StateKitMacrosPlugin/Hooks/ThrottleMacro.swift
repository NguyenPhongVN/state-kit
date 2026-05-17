import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ThrottleMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.onlyApplicableToFunctions
        }

        let functionName = funcDecl.name.text
        let throttledName = functionName + "_throttled"
        
        let modifiers = declaration.asProtocol(WithModifiersSyntax.self)?.modifiers
        let isStatic = modifiers?.contains { $0.name.text == "static" } ?? false
        let staticKeyword = isStatic ? "static " : ""

        // Extract milliseconds argument
        var milliseconds: Int = 0
        if let args = node.arguments?.as(LabeledExprListSyntax.self),
           let firstArg = args.first?.expression.as(IntegerLiteralExprSyntax.self) {
            milliseconds = Int(firstArg.literal.text) ?? 0
        }

        let lastExecName = "_\(functionName)LastExecution"
        
        let lastExecDecl: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)private var \(raw: lastExecName): Date = Date(timeIntervalSince1970: 0)
        """

        let throttledFunc: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)func \(raw: throttledName)() {
            let now = Date()
            let interval = TimeInterval(\(raw: milliseconds)) / 1000.0
            
            if now.timeIntervalSince(\(raw: lastExecName)) >= interval {
                \(raw: lastExecName) = now
                Task { await \(raw: functionName)() }
            }
        }
        """

        return [lastExecDecl, throttledFunc]
    }
}
