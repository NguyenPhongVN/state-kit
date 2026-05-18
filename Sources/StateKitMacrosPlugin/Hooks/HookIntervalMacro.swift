import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// HookIntervalMacro: @attached(peer, names: prefixed(use))
//
// Generates a peer function named "use<StructName>" that creates a
// repeating interval effect via useEffect.  The struct must provide
// a stored `intervalMs: Int` property and a `tick()` async method.
//
// ── Example ──────────────────────────────────────────────────────────
//   @HookInterval struct Poller {
//       var intervalMs: Int = 5000
//       func tick() async { /* poll */ }
//   }
//
// Expands to:
//   struct Poller { var intervalMs: Int = 5000; func tick() async {} }
//
//   @MainActor
//   func usePoller(intervalMs: Int = 5000) {
//       StateKit.useEffect(updateStrategy: .preserved(by: intervalMs)) {
//           let instance = Poller(intervalMs: intervalMs)
//           let task = Task {
//               while !Task.isCancelled {
//                   try? await Task.sleep(nanoseconds: UInt64(instance.intervalMs) * 1_000_000)
//                   if !Task.isCancelled {
//                       await instance.tick()
//                   }
//               }
//           }
//           return { task.cancel() }
//       }
//   }
//
// Usage:
//   usePoller()               // polls every 5000ms
//   usePoller(intervalMs: 1000) // re-runs, polls every 1000ms

public struct HookIntervalMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        guard PropertyExtractor.function(in: structDecl, named: "tick") != nil else {
            throw MacroError.custom("@HookInterval requires a 'tick()' method")
        }

        let className = structDecl.name.text
        let funcName = "use" + className

        let properties = PropertyExtractor.storedProperties(from: structDecl)

        let (accessPrefix, staticKeyword) = AttributeHelper.modifierPrefixes(from: structDecl)

        var paramList: [String] = []
        var depsList: [String] = []
        var instanceInit: [String] = []

        for prop in properties {
            paramList.append("\(prop.name): \(prop.typeName)")
            depsList.append(prop.name)
            instanceInit.append("    \(prop.name): \(prop.name)")
        }

        let params = paramList.joined(separator: ", ")
        let depsArg = depsList.isEmpty ? ".once" : ".preserved(by: \(depsList.joined(separator: ", ")))"
        let initCode = instanceInit.isEmpty ? "()" : "(\n" + instanceInit.joined(separator: ",\n") + "\n    )"

        let hookFunction: DeclSyntax = """
        @MainActor
        \(raw: accessPrefix)\(raw: staticKeyword)func \(raw: funcName)(\(raw: params)) {
            StateKit.useEffect(updateStrategy: \(raw: depsArg)) {
                let instance = \(raw: className)\(raw: initCode)
                let task = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: UInt64(instance.intervalMs) * 1_000_000)
                        if !Task.isCancelled {
                            await instance.tick()
                        }
                    }
                }
                return { task.cancel() }
            }
        }
        """

        return [hookFunction]
    }
}
