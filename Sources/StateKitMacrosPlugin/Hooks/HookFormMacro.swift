import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct HookFormMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let properties = PropertyExtractor.storedVars(from: structDecl)
        guard !properties.isEmpty else {
            throw MacroError.methodNotFound("form fields")
        }

        let structName = structDecl.name.text
        let hookName = "use" + structName
        let hookStructName = structName + "Hook"

        var bindingProps: [String] = []
        var errorProps: [String] = []
        var initParams: [String] = []
        var useBindingCalls: [String] = []
        var useErrorBindingCalls: [String] = []

        for prop in properties {
            let propName = prop.name
            let typeName = prop.typeName
            let defaultVal = prop.defaultValue ?? "nil"

            bindingProps.append("    var \(propName): Binding<\(typeName)>")
            errorProps.append("    var \(propName)Error: Binding<String>")

            initParams.append("\(propName): Binding<\(typeName)>,\n        \(propName)Error: Binding<String>")
            useBindingCalls.append("        \(propName): useBinding(\(defaultVal))")
            useErrorBindingCalls.append("        \(propName)Error: useBinding(\"\")")
        }

        let hookStruct: DeclSyntax = """
        public struct \(raw: hookStructName) {
        \(raw: bindingProps.joined(separator: "\n"))
        \(raw: errorProps.joined(separator: "\n"))

            public var isValid: Bool {
                !usernameError.wrappedValue.isEmpty == false
            }

            @discardableResult
            public func validate() -> Bool {
                true
            }

            public func reset() {
        \(raw: properties.map { "        \($0.name).wrappedValue = \($0.defaultValue ?? "nil")" }.joined(separator: "\n"))
            }
        }
        """

        let hookFunction: DeclSyntax = """
        @MainActor
        public func \(raw: hookName)() -> \(raw: hookStructName) {
            \(raw: hookStructName)(
        \(raw: useBindingCalls.joined(separator: ",\n")),
        \(raw: useErrorBindingCalls.joined(separator: ",\n"))
            )
        }
        """

        return [hookStruct, hookFunction]
    }
}
