private struct Effect {
    var deps: [AnyHashable]?
    var cleanup: (() -> Void)?
}

@MainActor public func useEffect(
    _ effect: @escaping () -> (() -> Void)?,
    deps: [AnyHashable]? = nil
) {
    guard let context = StateRuntime.current else {
        fatalError("\(#function) must be used inside StateRuntime")
    }
    let index = context.nextIndex()

    if index < context.states.count {

        guard let old = context.states[index] as? Effect else { return }

        if !areEqual(old.deps, deps) {

            old.cleanup?()

            let cleanup = effect()

            context.states[index] = Effect(
                deps: deps,
                cleanup: cleanup
            )
        }
    } else {

        let cleanup = effect()

        context.states.append(
            Effect(
                deps: deps,
                cleanup: cleanup
            )
        )
    }
}
