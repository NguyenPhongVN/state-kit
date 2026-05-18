import SwiftSyntax

// MARK: - AttributeListSyntax.Element

extension AttributeListSyntax.Element {

    /// Extract the simple attribute name.
    ///
    /// For bare attributes like `@MainActor` returns `"MainActor"`.
    /// For qualified names like `@StateKit.MainActor` returns the last component `"MainActor"`.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   @MainActor          → "MainActor"
    ///   @StateKit.MyAttr    → "MyAttr"
    ///   @available(iOS 17, *) → "available"
    var simpleName: String? {
        guard let attr = self.as(AttributeSyntax.self) else { return nil }
        let rawName = attr.attributeName.trimmedDescription
        return rawName.split(separator: ".").last.map(String.init) ?? rawName
    }
}

// MARK: - DeclGroupSyntax

extension DeclGroupSyntax {

    /// Human-readable kind name for the declaration group.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   struct Foo {}   → "struct"
    ///   class Bar {}    → "class"
    ///   actor Baz {}    → "actor"
    ///   enum Qux {}     → "enum"
    ///   protocol Quux {} → "protocol"
    var declarationKind: String {
        if self.is(StructDeclSyntax.self) { return "struct" }
        if self.is(ClassDeclSyntax.self) { return "class" }
        if self.is(ActorDeclSyntax.self) { return "actor" }
        if self.is(EnumDeclSyntax.self) { return "enum" }
        if self.is(ProtocolDeclSyntax.self) { return "protocol" }
        return "unknown"
    }

    /// All function declarations directly inside the member block.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   struct Foo {
    ///       func bar() {}
    ///       func baz() {}
    ///   }
    ///   // declaredFunctions → [bar, baz]
    var declaredFunctions: [FunctionDeclSyntax] {
        memberBlock.members.compactMap { $0.decl.as(FunctionDeclSyntax.self) }
    }

    /// All variable declarations directly inside the member block.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   struct Foo {
    ///       var x = 1
    ///       let y: String
    ///   }
    ///   // declaredVariables → [var x, let y]
    var declaredVariables: [VariableDeclSyntax] {
        memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }
    }

    /// All typealias declarations directly inside the member block.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   struct Foo {
    ///       typealias Value = Int
    ///       typealias Action = String
    ///   }
    ///   // declaredTypealiases → [Value, Action]
    var declaredTypealiases: [TypeAliasDeclSyntax] {
        memberBlock.members.compactMap { $0.decl.as(TypeAliasDeclSyntax.self) }
    }

    /// Simple names of all attributes on this declaration group.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   @MainActor
    ///   @available(iOS 17, *)
    ///   struct Foo {}
    ///   // attributesSimpleNames → ["MainActor", "available"]
    var attributesSimpleNames: [String] {
        attributes.compactMap(\.simpleName)
    }

    /// Check whether this declaration group has an attribute with the given simple name.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   @MainActor
    ///   struct Foo {}
    ///   // hasAttribute(named: "MainActor") → true
    ///   // hasAttribute(named: "Sendable") → false
    func hasAttribute(named name: String) -> Bool {
        attributes.contains { $0.simpleName == name }
    }

    /// Find the first function declaration with the given name.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   struct Foo {
    ///       func bar() {}
    ///       func bar(x: Int) {}
    ///   }
    ///   // function(named: "bar") → func bar()          (first match)
    ///   // function(named: "baz") → nil
    func function(named name: String) -> FunctionDeclSyntax? {
        declaredFunctions.first { $0.name.text == name }
    }

    /// All function declarations with the given name (handles overloads).
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   struct Foo {
    ///       func bar() {}
    ///       func bar(x: Int) {}
    ///   }
    ///   // functions(named: "bar") → [func bar(), func bar(x: Int)]
    func functions(named name: String) -> [FunctionDeclSyntax] {
        declaredFunctions.filter { $0.name.text == name }
    }

    /// Extract a typealias's underlying type as a trimmed string.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   struct Foo {
    ///       typealias Value = Int
    ///   }
    ///   // typealiasValue(named: "Value") → "Int"
    ///   // typealiasValue(named: "Missing") → nil
    func typealiasValue(named name: String) -> String? {
        declaredTypealiases.first(where: { $0.name.text == name })?.initializer.value.trimmedDescription
    }
}

// MARK: - WithModifiersSyntax

extension WithModifiersSyntax {

    /// Check whether a modifier with the given name exists.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   public static func foo() {}
    ///   // hasModifier("public") → true
    ///   // hasModifier("static") → true
    ///   // hasModifier("private") → false
    func hasModifier(_ name: String) -> Bool {
        modifiers.contains { $0.name.text == name }
    }

    /// The access level keyword as a string, if present.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   public struct Foo {}    → "public"
    ///   private class Bar {}    → "private"
    ///   struct Baz {}          → nil  (internal is implicit)
    ///   package struct Qux {}  → "package"
    var accessLevelKeyword: String? {
        modifiers
            .first(where: { ["private", "fileprivate", "internal", "package", "public", "open"].contains($0.name.text) })?
            .name
            .text
    }

    /// Access level keyword followed by a space, or empty string if internal.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   public func foo()    → "public "
    ///   func foo()           → ""
    ///   private func foo()   → "private "
    var accessPrefix: String {
        accessLevelKeyword.map { "\($0) " } ?? ""
    }

    /// The `static` keyword followed by a space, or empty string.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   static func foo()    → "static "
    ///   class func foo()     → "static "  (class members treated as static)
    ///   func foo()           → ""
    var staticKeyword: String {
        (hasModifier("static") || hasModifier("class")) ? "static " : ""
    }
}

// MARK: - FunctionDeclSyntax

extension FunctionDeclSyntax {

    /// Whether the function is marked `async`.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   func load() async -> Data    → true
    ///   func load() -> Data          → false
    var isAsync: Bool {
        signature.effectSpecifiers?.asyncSpecifier != nil
    }

    /// Whether the function is marked `throws`.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   func load() throws           → true
    ///   func load() async throws     → true
    ///   func load()                  → false
    var isThrowing: Bool {
        signature.effectSpecifiers?.throwsClause != nil
    }

    /// Whether the function is both `async` and `throws`.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   func load() async throws     → true
    ///   func load() async            → false
    ///   func load() throws           → false
    var isAsyncThrowing: Bool {
        isAsync && isThrowing
    }

    /// The function's return type, if present.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   func load() -> Data          → Data
    ///   func load()                  → nil
    ///   func load() async -> Int     → Int
    var returnType: TypeSyntax? {
        signature.returnClause?.type
    }

    /// The first-name labels of all parameters.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   func foo(context: Context, x: Int)    → ["context", "x"]
    ///   func bar(_ value: String)             → ["_"]
    ///   func baz()                            → []
    var parameterNames: [String] {
        signature.parameterClause.parameters.map { $0.firstName.text }
    }

    /// Check whether the first parameter has the given external label.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   func value(context: Context)          → hasFirstParameter(named: "context") == true
    ///   func value(_ ctx: Context)            → hasFirstParameter(named: "context") == false
    ///   func value()                          → hasFirstParameter(named: "context") == false
    func hasFirstParameter(named name: String) -> Bool {
        signature.parameterClause.parameters.first?.firstName.text == name
    }

    /// Check whether this function has an attribute with the given simple name.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   @discardableResult
    ///   func foo() {}
    ///   // hasAttribute(named: "discardableResult") → true
    ///   // hasAttribute(named: "MainActor") → false
    func hasAttribute(named name: String) -> Bool {
        attributes.contains { $0.simpleName == name }
    }
}

// MARK: - VariableDeclSyntax

extension VariableDeclSyntax {

    /// Whether the variable is marked `lazy`.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   lazy var x = 1     → true
    ///   var x = 1          → false
    var isLazy: Bool {
        modifiers.contains { $0.name.text == "lazy" }
    }

    /// Whether the variable is marked `static` or `class`.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   static var x = 1   → true
    ///   class var x: Int { return 1 }  → true
    ///   var x = 1          → false
    var isStaticOrClass: Bool {
        modifiers.contains { $0.name.text == "static" || $0.name.text == "class" }
    }

    /// All binding names in this variable declaration.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   let x = 1, y = 2           → ["x", "y"]
    ///   var name: String           → ["name"]
    ///   let (a, b) = (1, 2)        → []  (destructuring, not IdentifierPattern)
    var bindingNames: [String] {
        bindings.compactMap { $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text }
    }
}

// MARK: - PatternBindingSyntax

extension PatternBindingSyntax {

    /// The identifier name of this binding, if it uses a simple identifier pattern.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   let x = 1          → "x"
    ///   let (a, b) = (1, 2) → nil  (destructuring, not IdentifierPattern)
    var identifierName: String? {
        pattern.as(IdentifierPatternSyntax.self)?.identifier.text
    }

    /// The explicit type annotation, if present.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   let x: Int = 42    → "Int"
    ///   let x = 42         → nil
    var explicitTypeName: String? {
        typeAnnotation?.type.trimmedDescription
    }

    /// The initializer expression as text, if present.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   let x = 42                   → "42"
    ///   var items = [1, 2, 3]        → "[1, 2, 3]"
    ///   var name: String             → nil
    var initializerValueText: String? {
        initializer?.value.trimmedDescription
    }

    /// Whether this binding is a computed property (has getter, setter, etc.).
    ///
    /// Observer-only properties (`willSet`/`didSet`) return `false` since they
    /// still have storage.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   var x: Int { return 1 }         → true  (getter)
    ///   var x: Int { get { 1 } set {} } → true  (get+set)
    ///   var x: Int { willSet {} }       → false (observer only, still stored)
    ///   var x: Int = 0                  → false (stored)
    var isComputedProperty: Bool {
        guard let accessorBlock else { return false }

        switch accessorBlock.accessors {
        case .getter:
            return true
        case .accessors(let accessors):
            let computedKinds: Set<String> = ["get", "set", "read", "modify", "_read", "_modify"]
            return accessors.contains {
                guard let accessorDecl = $0.as(AccessorDeclSyntax.self) else { return false }
                return computedKinds.contains(accessorDecl.accessorSpecifier.text)
            }
        }
    }
}

// MARK: - TypeSyntax

extension TypeSyntax {

    /// Recursively unwrap optional, IUO, attributed, and `some`/`any` wrappers
    /// to reveal the underlying concrete type.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   Int?                        → Int
    ///   Int!                        → Int
    ///   @Sendable Int               → Int
    ///   some Equatable              → Equatable
    ///   any Numeric                 → Numeric
    ///   Array<Int>                  → Array<Int>  (no-op)
    var unwrappedType: TypeSyntax {
        if let optionalType = self.as(OptionalTypeSyntax.self) {
            return optionalType.wrappedType.unwrappedType
        }
        if let iuoType = self.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return iuoType.wrappedType.unwrappedType
        }
        if let attributedType = self.as(AttributedTypeSyntax.self) {
            return attributedType.baseType.unwrappedType
        }
        if let someOrAnyType = self.as(SomeOrAnyTypeSyntax.self) {
            return someOrAnyType.constraint.unwrappedType
        }
        return self
    }

    /// Extract generic arguments from an identifier or member type.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   Array<Int>                  → [Int]
    ///   Result<Data, Error>         → [Data, Error]
    ///   Swift.Result<Int, String>   → [Int, String]
    ///   Int                         → []
    ///   Int?                        → []  (optional unwraps to Int, not generic)
    var genericArguments: [TypeSyntax] {
        let unwrapped = unwrappedType

        if let identifierType = unwrapped.as(IdentifierTypeSyntax.self),
           let genericClause = identifierType.genericArgumentClause {
            return genericClause.arguments.map { TypeSyntax("\(raw: $0.argument)") }
        }

        if let memberType = unwrapped.as(MemberTypeSyntax.self),
           let genericClause = memberType.genericArgumentClause {
            return genericClause.arguments.map { TypeSyntax("\(raw: $0.argument)") }
        }

        return []
    }

    /// The last component of a qualified type name.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   Swift.Array<Int>            → "Array<Int>"
    ///   Int                         → "Int"
    ///   Swift.Result<Data, Error>   → "Result<Data, Error>"
    var simpleName: String {
        let text = unwrappedType.trimmedDescription
        return text.split(separator: ".").last.map(String.init) ?? text
    }

    /// Whether the type is optional (`T?`) or implicitly unwrapped optional (`T!`).
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   Int?         → true
    ///   String!      → true
    ///   Int          → false
    ///   Array<Int>   → false
    var isOptionalLike: Bool {
        self.is(OptionalTypeSyntax.self) || self.is(ImplicitlyUnwrappedOptionalTypeSyntax.self)
    }
}
