import SwiftSyntax

/// Utilities for reading attributes and access control modifiers from Swift syntax nodes.
///
/// Used throughout StateKit macros to propagate access levels, check for `@MainActor`,
/// and extract attribute names without duplicating traversal logic.
///
/// ## Overview
/// - `attributeNames(on:)` — list all attribute names on a declaration or function
/// - `hasAttribute(_:on:)` — check for a specific attribute
/// - `hasAnyAttribute(_:on:)` — check for any of a list of attributes
/// - `accessLevel(from:)` — extract access modifier from a type declaration
/// - `modifierPrefixes(from:)` — extract (accessPrefix, staticKeyword) from any `WithModifiersSyntax`
/// - `mainActor` / `mainActorNewline` — pre-built `@MainActor` attribute syntax
enum AttributeHelper {

    /// Return the simple names of all attributes on a type declaration.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   @MainActor
    ///   @available(iOS 17, *)
    ///   struct MyView { ... }
    ///   // attributeNames(on:) → ["MainActor", "available"]
    static func attributeNames(on declaration: some DeclGroupSyntax) -> [String] {
        declaration.attributes.compactMap { normalizedAttributeName(from: $0) }
    }

    /// Return the simple names of all attributes on a function.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   @discardableResult
    ///   public func fetch() async -> Data { ... }
    ///   // attributeNames(on:) → ["discardableResult"]
    static func attributeNames(on function: FunctionDeclSyntax) -> [String] {
        function.attributes.compactMap { normalizedAttributeName(from: $0) }
    }

    /// Check whether a type declaration carries a specific attribute.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   hasAttribute("MainActor", on: myStructDecl) → true/false
    static func hasAttribute(_ name: String, on declaration: some DeclGroupSyntax) -> Bool {
        declaration.attributes.contains { matchesAttribute($0, name: name) }
    }

    /// Check whether a function carries a specific attribute.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   hasAttribute("discardableResult", on: myFuncDecl) → true/false
    static func hasAttribute(_ name: String, on function: FunctionDeclSyntax) -> Bool {
        function.attributes.contains { matchesAttribute($0, name: name) }
    }

    /// Pre-built `@MainActor` attribute (newline trailing trivia).
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   // Use when generating:
    ///   struct Foo {
    ///   \\(AttributeHelper.mainActor)
    ///       var value: Int
    ///   }
    static var mainActor: AttributeSyntax {
        AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("MainActor")))
            .with(\.atSign, .atSignToken())
            .with(\.trailingTrivia, .newlines(1))
    }

    static var mainActorNewline: AttributeSyntax {
        AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("MainActor")))
            .with(\.atSign, .atSignToken())
            .with(\.trailingTrivia, .newlines(1))
    }

    /// Extract the access level modifier from a type declaration.
    ///
    /// Returns the modifier followed by a space, or an empty string for `internal`
    /// (which is the default and is typically omitted in source code).
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   public struct Foo {}     → "public "
    ///   struct Foo {}            → ""
    ///   private struct Foo {}    → "private "
    ///   package struct Foo {}    → "package "
    static func accessLevel(from decl: some DeclGroupSyntax) -> String {
        let modifiers: DeclModifierListSyntax
        if let structDecl = decl.as(StructDeclSyntax.self) {
            modifiers = structDecl.modifiers
        } else if let classDecl = decl.as(ClassDeclSyntax.self) {
            modifiers = classDecl.modifiers
        } else if let actorDecl = decl.as(ActorDeclSyntax.self) {
            modifiers = actorDecl.modifiers
        } else if let enumDecl = decl.as(EnumDeclSyntax.self) {
            modifiers = enumDecl.modifiers
        } else if let protocolDecl = decl.as(ProtocolDeclSyntax.self) {
            modifiers = protocolDecl.modifiers
        } else {
            return ""
        }

        let level = modifiers.first(where: {
            ["private", "fileprivate", "internal", "package", "public", "open"].contains($0.name.text)
        })
        return level.map { "\($0.name.text) " } ?? ""
    }

    /// Extract the access prefix and static keyword from any declaration with modifiers.
    ///
    /// This is the preferred helper for **function-attached** macros (like `@Debounce`,
    /// `@Throttle`) where you need to reproduce the signature's access and static-ness.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   public func foo()     → ("public ", "")
    ///   static func foo()     → ("", "static ")
    ///   public static func foo() → ("public ", "static ")
    ///   func foo()            → ("", "")
    static func modifierPrefixes(from decl: some WithModifiersSyntax) -> (accessPrefix: String, staticKeyword: String) {
        let accessLevel = decl.modifiers.first(where: {
            ["private", "fileprivate", "internal", "package", "public", "open"].contains($0.name.text)
        })
        let accessPrefix = accessLevel.map { "\($0.name.text) " } ?? ""
        let isStatic = decl.modifiers.contains { $0.name.text == "static" || $0.name.text == "class" }
        let staticKeyword = isStatic ? "static " : ""
        return (accessPrefix, staticKeyword)
    }

    /// Check whether a declaration has any of the given attributes.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   hasAnyAttribute(["MainActor", "Sendable"], on: myStructDecl)
    static func hasAnyAttribute(_ names: [String], on declaration: some DeclGroupSyntax) -> Bool {
        names.contains { hasAttribute($0, on: declaration) }
    }

    /// Check whether a function has any of the given attributes.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   hasAnyAttribute(["discardableResult", "Sendable"], on: myFuncDecl)
    static func hasAnyAttribute(_ names: [String], on function: FunctionDeclSyntax) -> Bool {
        names.contains { hasAttribute($0, on: function) }
    }

    /// Check whether an attribute list element matches a given simple name.
    ///
    /// Handles both bare names (`MainActor`) and qualified names (`SwiftUI.State`).
    private static func matchesAttribute(_ attribute: AttributeListSyntax.Element, name: String) -> Bool {
        guard let attr = attribute.as(AttributeSyntax.self) else { return false }

        if let identifier = attr.attributeName.as(IdentifierTypeSyntax.self)?.name.text {
            return identifier == name
        }

        if let member = attr.attributeName.as(MemberTypeSyntax.self) {
            let fullName = member.trimmedDescription
            return fullName == name || fullName.hasSuffix(".\(name)")
        }

        let rawName = attr.attributeName.trimmedDescription
        return rawName == name || rawName.hasSuffix(".\(name)")
    }

    /// Strip module qualifiers from an attribute to get the simple name.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   "MainActor"        → "MainActor"
    ///   "SwiftUI.State"    → "State"
    ///   "NSApplicationDelegateAdaptor" → "NSApplicationDelegateAdaptor"
    private static func normalizedAttributeName(from attribute: AttributeListSyntax.Element) -> String? {
        guard let attr = attribute.as(AttributeSyntax.self) else { return nil }
        let rawName = attr.attributeName.trimmedDescription
        if let last = rawName.split(separator: ".").last {
            return String(last)
        }
        return rawName
    }
}
