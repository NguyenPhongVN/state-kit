import Foundation

enum MacroError: Error, CustomStringConvertible {
    case onlyApplicableToStructs
    case onlyApplicableToClasses
    case onlyApplicableToFunctions
    case methodNotFound(String)
    case multipleMethodsFound(String)
    case ambiguousAtomType
    case invalidReturnType
    case missingBaseClass
    case invalidHookName(String)
    case missingRunMethod
    case missingComputeMethod
    case missingReduceMethod
    case invalidAtomFamily(String)
    case missingValueMethod
    case missingTaskMethod
    case custom(String)

    var description: String {
        switch self {
        case .onlyApplicableToStructs:
            return "@StateAtom, @ValueAtom, @TaskAtom, @ThrowingTaskAtom, @PublisherAtom, and @Atom can only be applied to structs"
        case .onlyApplicableToClasses:
            return "@riverpodNotifier can only be applied to classes"
        case .onlyApplicableToFunctions:
            return "@Hook and @CustomHook can only be applied to functions"
        case .methodNotFound(let name):
            return "Required method '\(name)' not found"
        case .multipleMethodsFound(let name):
            return "Multiple definitions of method '\(name)' found"
        case .ambiguousAtomType:
            return "@Atom could not determine atom type — struct must have exactly one of: defaultValue(context:), value(context:), task(context:), or publisher(context:)"
        case .invalidReturnType:
            return "Invalid or unsupported return type"
        case .missingBaseClass:
            return "Class must inherit from Notifier or AsyncNotifier"
        case .invalidHookName(let name):
            return "Hook function '\(name)' must start with 'use' (e.g., 'use\(name.prefix(1).uppercased())\(name.dropFirst())')"
        case .missingRunMethod:
            return "@HookEffect requires a 'run()' method"
        case .missingComputeMethod:
            return "@HookMemo requires a 'compute()' method"
        case .missingReduceMethod:
            return "@HookReducer requires a 'reduce(_:action:)' method"
        case .invalidAtomFamily(let reason):
            return "Invalid atom family: \(reason)"
        case .missingValueMethod:
            return "@SelectorFamily requires a 'value(context:)' method"
        case .missingTaskMethod:
            return "@AsyncTaskFamily requires a 'task(context:)' method"
        case .custom(let message):
            return message
        }
    }
}
