struct Callback<T> {
    var fn: T
    var deps: [AnyHashable]?
}

@MainActor
func useCallback<T>(
    _ callback: T,
    deps: [AnyHashable]? = nil
) -> T {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside HookView")
    }
    let index = context.nextIndex()

    if index < context.states.count {

        if let old = context.states[index] as? Callback<T> {

            if !areEqual(old.deps, deps) {

                let new = Callback(fn: callback, deps: deps)
                context.states[index] = new
                return callback

            } else {

                return old.fn
            }

        } else {

            context.states[index] = Callback(fn: callback, deps: deps)
            return callback
        }

    } else {
        let cb = Callback(fn: callback, deps: deps)
        context.states.append(cb)
        return callback
    }
}
