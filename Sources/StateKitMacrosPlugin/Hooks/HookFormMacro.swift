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

        let properties = PropertyExtractor.storedProperties(from: structDecl)
        guard !properties.isEmpty else {
            throw MacroError.methodNotFound("form fields")
        }

        let structName = structDecl.name.text
        let hookName = "use" + structName
        let hookStructName = structName + "Hook"

        var bindingProps: [String] = []
        var errorProps: [String] = []
        var useBindingCalls: [String] = []
        var useErrorBindingCalls: [String] = []

        for prop in properties {
            let propName = prop.name
            let typeName = prop.typeName
            let defaultVal = prop.defaultValue ?? "nil"

            bindingProps.append("    public var \(propName): Binding<\(typeName)>")
            errorProps.append("    public var \(propName)Error: Binding<String>")

            useBindingCalls.append("        \(propName): useBinding(\(defaultVal))")
            useErrorBindingCalls.append("        \(propName)Error: useBinding(\"\")")
        }

        let errorChecks = properties.map { "\($0.name)Error.wrappedValue.isEmpty" }.joined(separator: " && ")

        let hookStruct: DeclSyntax = """
        public struct \(raw: hookStructName) {
        \(raw: bindingProps.joined(separator: "\n"))
        \(raw: errorProps.joined(separator: "\n"))

            public var isValid: Bool {
                \(raw: errorChecks)
            }

            @discardableResult
            public func validate() -> Bool {
                // Basic validation: all fields must not be empty if they are Strings
                var allValid = true
        \(raw: properties.filter { $0.typeName == "String" }.map { "        if \($0.name).wrappedValue.isEmpty { \($0.name)Error.wrappedValue = \"Required\"; allValid = false }" }.joined(separator: "\n"))
                return allValid
            }

            public func reset() {
        \(raw: properties.map { "        \($0.name).wrappedValue = \($0.defaultValue ?? "nil")" }.joined(separator: "\n"))
        \(raw: properties.map { "        \($0.name)Error.wrappedValue = \"\"" }.joined(separator: "\n"))
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
