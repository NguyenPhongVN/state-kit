import Foundation
import SwiftUI

fileprivate final class _LayoutEffectBox {
    var depsHash: Int?
    var cleanup: (() -> Void)?
}

fileprivate struct _LayoutEffectStore {
    @MainActor static var boxes: [AnyHashable: _LayoutEffectBox] = [:]
}

public protocol LayoutEffectDependencies {
    var layoutDepsHash: Int { get }
}

extension LayoutEffectDependencies where Self: Hashable {
    public var layoutDepsHash: Int { self.hashValue }
}

extension Array: LayoutEffectDependencies where Element: Hashable {}
extension Optional: LayoutEffectDependencies where Wrapped: Hashable {}

/// Runs an effect after layout updates when `deps` changes, and cleans up before the next run or when cleared.
/// The returned function can be used to manually clear the effect (invoking cleanup if any).
@MainActor
@discardableResult
public func useLayoutEffect<Deps: LayoutEffectDependencies>(key: AnyHashable, deps: Deps, _ effect: @escaping () -> (() -> Void)?) -> () -> Void {
    let currentHash = deps.layoutDepsHash

    let box = _LayoutEffectStore.boxes[key] ?? _LayoutEffectBox()
    let previousHash = box.depsHash

    if previousHash == nil || previousHash != currentHash {
        // Deps changed: cleanup then schedule effect
        box.depsHash = currentHash
        let previousCleanup = box.cleanup
        box.cleanup = nil

        // Perform cleanup synchronously before scheduling the next effect
        previousCleanup?()

        // Schedule effect to run on the next runloop tick (post-update on main)
        DispatchQueue.main.async {
            let newCleanup = effect()
            Task { @MainActor in
                box.cleanup = newCleanup
            }
        }
    }

    _LayoutEffectStore.boxes[key] = box

    // Return a disposer that clears and runs cleanup
    let disposer: () -> Void = { [weak box] in
        guard let box else { return }
        let c = box.cleanup
        box.cleanup = nil
        c?()
        _LayoutEffectStore.boxes.removeValue(forKey: key)
    }

    return disposer
}

fileprivate struct _LayoutDepsBox<Base: Hashable>: LayoutEffectDependencies {
    let base: Base
    var layoutDepsHash: Int { base.hashValue }
    init(base: Base) { self.base = base }
}

/// Hashable convenience overload
@MainActor
@discardableResult
public func useLayoutEffect<Deps: Hashable>(key: AnyHashable, deps: Deps, _ effect: @escaping () -> (() -> Void)?) -> () -> Void {
    return useLayoutEffect(key: key, deps: _LayoutDepsBox(base: deps), effect)
}

/// No-deps overload: runs once, then only cleans up when disposed.
@MainActor
@discardableResult
public func useLayoutEffect(key: AnyHashable, _ effect: @escaping () -> (() -> Void)?) -> () -> Void {
    return useLayoutEffect(key: key, deps: 0, effect)
}

/// Explicit clear helper for symmetry
@MainActor
public func clearLayoutEffect(key: AnyHashable) {
    if let box = _LayoutEffectStore.boxes[key] {
        let c = box.cleanup
        box.cleanup = nil
        c?()
    }
    _LayoutEffectStore.boxes.removeValue(forKey: key)
}

