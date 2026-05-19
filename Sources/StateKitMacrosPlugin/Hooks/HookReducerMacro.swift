import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// HookReducerMacro: @attached(peer, names: prefixed(use))
//
// Generates a peer function named "use<StructName>" that wraps useReducer.
// The struct provides typealiases for State/Action and a reduce method.
//
// ── Example ──────────────────────────────────────────────────────────
//   @HookReducer struct Counter {
//       typealias State = Int
//       typealias Action = String
//       func reduce(_ s: inout Int, action: String) {
//           if action == "add" { s += 1 }
//       }
//   }
//
// Expands to:
//   struct Counter { ... }
//
//   @MainActor
//   func useCounter(initial: Int = Int()) -> (Int, (String) -> Void) {
//       let reducer = Counter()
//       return StateKit.useReducer(initial) { state, action in
//           reducer.reduce(&state, action: action)
//       }
//   }
//
// Usage:
//   var (count, dispatch) = useCounter(initial: 10)
//   dispatch("add")
//   (count, dispatch) = useCounter(initial: 10)  // still 11 (persisted)

public struct HookReducerMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let className = structDecl.name.text
        let funcName = "use" + className

        let (accessPrefix, staticKeyword) = AttributeHelper.modifierPrefixes(from: structDecl)

        // Extract State and Action from either:
        // 1) typealias State/Action
        // 2) nested struct/enum/class State/Action
        var stateType: String?
        var actionType: String?

        for member in structDecl.memberBlock.members {
            if let typealiasDecl = member.decl.as(TypeAliasDeclSyntax.self) {
                if typealiasDecl.name.text == "State" {
                    stateType = typealiasDecl.initializer.value.trimmedDescription
                } else if typealiasDecl.name.text == "Action" {
                    actionType = typealiasDecl.initializer.value.trimmedDescription
                }
            }

            if stateType == nil {
                if let nestedStruct = member.decl.as(StructDeclSyntax.self), nestedStruct.name.text == "State" {
                    stateType = "\(className).State"
                } else if let nestedClass = member.decl.as(ClassDeclSyntax.self), nestedClass.name.text == "State" {
                    stateType = "\(className).State"
                }
            }

            if actionType == nil {
                if let nestedEnum = member.decl.as(EnumDeclSyntax.self), nestedEnum.name.text == "Action" {
                    actionType = "\(className).Action"
                } else if let nestedStruct = member.decl.as(StructDeclSyntax.self), nestedStruct.name.text == "Action" {
                    actionType = "\(className).Action"
                } else if let nestedClass = member.decl.as(ClassDeclSyntax.self), nestedClass.name.text == "Action" {
                    actionType = "\(className).Action"
                }
            }
        }

        let resolvedStateType = stateType ?? "Any"
        let resolvedActionType = actionType ?? "Any"

        let hookDecl: DeclSyntax = """
        @MainActor
        \(raw: accessPrefix)\(raw: staticKeyword)func \(raw: funcName)(initial: \(raw: resolvedStateType) = \(raw: resolvedStateType)()) -> (\(raw: resolvedStateType), (\(raw: resolvedActionType)) -> Void) {
            let reducer = \(raw: className)()
            return StateKit.useReducer(initial) { state, action in
                reducer.reduce(&state, action: action)
            }
        }
        """

        return [hookDecl]
    }
}
