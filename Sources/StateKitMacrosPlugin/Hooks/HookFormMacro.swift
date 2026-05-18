import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// HookFormMacro: @attached(peer, names: prefixed(use), named(FHook))
//
// Generates TWO peer declarations:
//   1. A public struct `FHook` with Binding<…> properties for each field,
//      plus `isValid`, `validate()`, and `reset()` helpers.
//   2. A function `use<StructName>() -> FHook` that creates the form via
//      useBinding for each field + useBinding("") for each error field.
//
// ── Example ──────────────────────────────────────────────────────────
//   @HookForm struct Profile {
//       var name: String = ""
//       var bio: String = ""
//   }
//
// Expands to:
//   struct Profile { var name: String = ""; var bio: String = "" }
//
//   public struct FHook {
//       public var name: Binding<String>
//       public var nameError: Binding<String>
//       public var bio: Binding<String>
//       public var bioError: Binding<String>
//
//       public var isValid: Bool { nameError.wrappedValue.isEmpty && bioError.wrappedValue.isEmpty }
//       @discardableResult func validate() -> Bool { ... }
//       func reset() { ... }
//   }
//
//   @MainActor
//   func useProfile() -> FHook {
//       FHook(
//           name: StateKit.useBinding(""),
//           nameError: StateKit.useBinding(""),
//           bio: StateKit.useBinding(""),
//           bioError: StateKit.useBinding("")
//       )
//   }
//
// Usage:
//   let form = useProfile()
//   form.name.wrappedValue = "Alice"
//   form.isValid          // true

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

        let className = structDecl.name.text
        let funcName = "use" + className

        let (accessPrefix, staticKeyword) = AttributeHelper.modifierPrefixes(from: structDecl)

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

            useBindingCalls.append("        \(propName): StateKit.useBinding(\(defaultVal))")
            useErrorBindingCalls.append("        \(propName)Error: StateKit.useBinding(\"\")")
        }

        let errorChecks = properties.map { "\($0.name)Error.wrappedValue.isEmpty" }.joined(separator: " && ")

        let hookStruct: DeclSyntax = """
        public struct FHook {
        \(raw: bindingProps.joined(separator: "\n"))
        \(raw: errorProps.joined(separator: "\n"))

            public var isValid: Bool {
                \(raw: errorChecks)
            }

            @discardableResult
            func validate() -> Bool {
                var allValid = true
        \(raw: properties.filter { $0.typeName == "String" }.map { "        if \($0.name).wrappedValue.isEmpty { \($0.name)Error.wrappedValue = \"Required\"; allValid = false }" }.joined(separator: "\n"))
                return allValid
            }

            func reset() {
        \(raw: properties.map { "        \($0.name).wrappedValue = \($0.defaultValue ?? "nil")" }.joined(separator: "\n"))
        \(raw: properties.map { "        \($0.name)Error.wrappedValue = \"\"" }.joined(separator: "\n"))
            }
        }
        """

        let hookFunction: DeclSyntax = """
        @MainActor
        \(raw: accessPrefix)\(raw: staticKeyword)func \(raw: funcName)() -> FHook {
            FHook(
        \(raw: useBindingCalls.joined(separator: ",\n")),
        \(raw: useErrorBindingCalls.joined(separator: ",\n"))
            )
        }
        """

        return [hookStruct, hookFunction]
    }
}
