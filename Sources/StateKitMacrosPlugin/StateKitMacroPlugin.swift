import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct StateKitMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AtomMacro.self,
        NotifierProviderMacro.self
    ]
}
