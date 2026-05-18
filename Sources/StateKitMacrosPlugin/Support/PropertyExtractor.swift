import SwiftSyntax

/// Metadata for a stored property extracted from a declaration.
///
/// ── Example ──────────────────────────────────────────────────────────
///   For `let count: Int = 0`:
///     PropertyInfo(name: "count", typeName: "Int", defaultValue: "0")
///
///   For `var name: String`:
///     PropertyInfo(name: "name", typeName: "String", defaultValue: nil)
struct PropertyInfo {
    let name: String
    let typeName: String
    let defaultValue: String?
}

/// Utility for extracting stored properties, typealiases, and functions from `DeclGroupSyntax`.
///
/// Used by Hook macros to inspect struct bodies and generate `use<Name>` peer functions
/// with matching parameter signatures.
///
/// ## What counts as a "stored property"
/// - `var` and `let` instance members (not `static`/`class`)
/// - Properties with or without initial values
/// - Properties with `willSet`/`didSet` observers
///
/// ## What is excluded
/// - Computed properties (`get`/`set`/`read`/`modify`)
/// - Static/class properties
/// - Lazy properties (Swift memberwise init excludes them)
/// - Property wrappers (`@State`, `@Binding`, etc.) — handled by their own macro
enum PropertyExtractor {

    /// Returns the names of all stored properties in a declaration group.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   struct Counter {
    ///       var count: Int = 0
    ///       var label: String
    ///       var total: Int { count * 2 }  // computed, excluded
    ///   }
    ///   // storedPropertyNames(from:) → ["count", "label"]
    static func storedPropertyNames(from decl: DeclGroupSyntax) -> [String] {
        storedProperties(from: decl).map(\.name)
    }

    /// Check whether a stored property with the given name exists.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   hasStoredProperty(in: counterStruct, named: "count")  → true
    ///   hasStoredProperty(in: counterStruct, named: "total")  → false (computed)
    static func hasStoredProperty(in decl: DeclGroupSyntax, named name: String) -> Bool {
        storedProperties(from: decl).contains { $0.name == name }
    }

    /// Returns the first stored property, or `nil` if there are none.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   struct MyStruct { var a = 1; var b = 2 }
    ///   // firstStoredProperty(from:) → PropertyInfo(name: "a", typeName: "Int", defaultValue: "1")
    static func firstStoredProperty(from decl: DeclGroupSyntax) -> PropertyInfo? {
        storedProperties(from: decl).first
    }

    /// Extract all stored properties from a declaration group.
    ///
    /// Iterates the member block, collecting non-lazy, non-computed, non-static
    /// variable declarations. Each binding produces one `PropertyInfo`.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   struct SearchBar {
    ///       @Binding var query: String     // excluded (property wrapper → not a plain var)
    ///       var isEditing = false          // → ("isEditing", "Bool", "false")
    ///       let placeholder: String        // → ("placeholder", "String", nil)
    ///       var debounceTask: Task?        // → ("debounceTask", "Task?", nil)
    ///       var canSearch: Bool { !query.isEmpty }  // excluded (computed)
    ///   }
    static func storedProperties(from decl: DeclGroupSyntax) -> [PropertyInfo] {
        var properties: [PropertyInfo] = []

        for member in decl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
            let specifier = varDecl.bindingSpecifier.text
            guard specifier == "var" || specifier == "let" else { continue }
            if varDecl.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) { continue }

            for binding in varDecl.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }

                if isComputedProperty(binding) { continue }
                if varDecl.modifiers.contains(where: { $0.name.text == "lazy" }) { continue }

                let name = pattern.identifier.text
                let typeName = binding.typeAnnotation?.type.trimmedDescription ?? "Unknown"
                let defaultValue = binding.initializer?.value.trimmedDescription

                properties.append(PropertyInfo(
                    name: name,
                    typeName: typeName,
                    defaultValue: defaultValue
                ))
            }
        }

        return properties
    }

    /// Extract all typealiases as a dictionary keyed by name.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   struct MyReducer {
    ///       typealias State = Int
    ///       typealias Action = String
    ///   }
    ///   // typealiases(from:) → ["State": "Int", "Action": "String"]
    static func typealiases(from decl: DeclGroupSyntax) -> [String: String] {
        var result: [String: String] = [:]

        for member in decl.memberBlock.members {
            guard let typeAlias = member.decl.as(TypeAliasDeclSyntax.self) else { continue }
            let name = typeAlias.name.text
            let type = typeAlias.initializer.value.trimmedDescription
            result[name] = type
        }

        return result
    }

    /// Extract all function declarations from the member block.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   struct Counter {
    ///       func increment() {}
    ///       func reset() {}
    ///   }
    ///   // functions(from:) → [increment, reset]
    static func functions(from decl: DeclGroupSyntax) -> [FunctionDeclSyntax] {
        var functions: [FunctionDeclSyntax] = []

        for member in decl.memberBlock.members {
            if let fn = member.decl.as(FunctionDeclSyntax.self) {
                functions.append(fn)
            }
        }

        return functions
    }

    /// Find the first function with the given name.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   function(in: counterStruct, named: "increment")
    ///   // → FunctionDeclSyntax for `func increment()`
    static func function(in decl: DeclGroupSyntax, named: String) -> FunctionDeclSyntax? {
        functions(from: decl).first { $0.name.text == named }
    }

    /// All functions with the given name (handles overloads).
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   functions(in: apiStruct, named: "fetch")
    ///   // → [func fetch() async, func fetch(id: Int) async]
    static func functions(in decl: DeclGroupSyntax, named: String) -> [FunctionDeclSyntax] {
        functions(from: decl).filter { $0.name.text == named }
    }

    /// Check whether a pattern binding is a computed property (has get/set/read/modify).
    ///
    /// Observer-only properties (`willSet`/`didSet`) return `false` since they
    /// still have storage.
    ///
    /// ── Example ──────────────────────────────────────────────────────────
    ///   var x: Int { return 1 }         → true  (getter)
    ///   var x: Int { get { 1 } set {} } → true  (get+set)
    ///   var x: Int { willSet {} }       → false (observer only, still stored)
    ///   var x: Int = 0                  → false (stored)
    private static func isComputedProperty(_ binding: PatternBindingSyntax) -> Bool {
        guard let accessorBlock = binding.accessorBlock else { return false }

        switch accessorBlock.accessors {
        case .getter:
            return true
        case .accessors(let accessors):
            let computedAccessorKinds: Set<String> = ["get", "set", "read", "modify", "_read", "_modify"]
            return accessors.contains {
                guard let accessorDecl = $0.as(AccessorDeclSyntax.self) else { return false }
                return computedAccessorKinds.contains(accessorDecl.accessorSpecifier.text)
            }
        }
    }
}
