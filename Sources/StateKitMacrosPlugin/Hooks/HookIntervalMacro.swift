import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @HookInterval: Interval/polling hook for periodic tasks
/// Automatically handles setup/cleanup of interval timers
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

        let properties = PropertyExtractor.storedProperties(from: structDecl)
        let structName = structDecl.name.text
        let hookName = "use" + structName

        var paramList: [String] = []
        var depsList: [String] = []
        var instanceInit: [String] = []

        for prop in properties {
            paramList.append("\(prop.name): \(prop.typeName)")
            depsList.append(prop.name)
            instanceInit.append("    \(prop.name): \(prop.name)")
        }

        let params = paramList.joined(separator: ", ")
        let deps = depsList.isEmpty ? "" : ".preserved(by: \(depsList.joined(separator: ", ")))"
        let initCode = instanceInit.isEmpty ? "()" : "(\n" + instanceInit.joined(separator: ",\n") + "\n    )"

        let hookFunction: DeclSyntax = """
        @MainActor
        public func \(raw: hookName)(\(raw: params)) {
            useEffect(updateStrategy: \(raw: deps)) {
                let instance = \(raw: structName)\(raw: initCode)
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
