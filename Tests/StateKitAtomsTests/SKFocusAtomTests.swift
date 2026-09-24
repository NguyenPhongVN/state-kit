import Testing
import StateKit
@testable import StateKitAtoms

private struct Profile: Equatable, Sendable {
    var email: String
    var name: String
}

private struct ProfileAtom: SKStateAtom, Hashable {
    typealias Value = Profile

    func defaultValue(context: SKAtomTransactionContext) -> Profile {
        Profile(email: "seed@statekit.dev", name: "Seed")
    }
}

@MainActor
@Suite("SKFocusAtom")
struct SKFocusAtomTests {

    @Test("writing through the focus updates the base with exactly one field changed")
    func writeThrough() {
        let store = SKAtomStore()
        let base = ProfileAtom()
        let focus = base.focus(\.email)

        focus.set("new@statekit.dev", in: store)

        let box: SKAtomBox<Profile>? = store.existingBox(for: SKAtomKey(base))
        let value = box?.value
        #expect(value?.email == "new@statekit.dev")
        #expect(value?.name == "Seed", "only the focused field may change")
    }

    @Test("focus reads reflect external base changes")
    func readReflectsBase() {
        let store = SKAtomStore()
        let base = ProfileAtom()
        let focus = base.focus(\.email)

        // Materialize the focus box (registers the focus -> base dependency
        // and its recomputer), then change the base externally.
        let focusBox: SKAtomBox<String> = store.valueBox(for: focus)
        #expect(focusBox.value == "seed@statekit.dev")

        store.setStateValue(Profile(email: "changed@x.io", name: "Seed"), for: base)

        #expect(focusBox.value == "changed@x.io",
                "the focus must recompute when the base atom changes")
    }

    @Test("base dependents recompute when the focus is written")
    func baseDependentsRecompute() {
        let store = SKAtomStore()
        let base = ProfileAtom()
        let focus = base.focus(\.email)

        // A derived atom over the base: uppercased email.
        struct EmailBadge: SKValueAtom, Hashable {
            typealias Value = String

            @MainActor
            func value(context: SKAtomTransactionContext) -> String {
                (context.watch(ProfileAtom()).email).uppercased()
            }
        }

        let badge: SKAtomBox<String> = store.valueBox(for: EmailBadge())
        let initialBadge = badge.value
        #expect(initialBadge == "SEED@STATEKIT.DEV")

        focus.set("fresh@statekit.dev", in: store)

        let recomputedBox: SKAtomBox<String> = store.valueBox(for: EmailBadge())
        let recomputed = recomputedBox.value
        #expect(recomputed == "FRESH@STATEKIT.DEV",
                "base dependents must recompute after a focus write")
    }

    @Test("distinct key paths are distinct atoms")
    func distinctKeyPaths() {
        let base = ProfileAtom()
        let emailFocus = base.focus(\.email)
        let nameFocus = base.focus(\.name)

        #expect(SKAtomKey(emailFocus) != SKAtomKey(nameFocus))
    }

    @Test("same base and key path share one atom identity")
    func sameIdentity() {
        let base = ProfileAtom()
        #expect(SKAtomKey(base.focus(\.email)) == SKAtomKey(base.focus(\.email)))
    }
}
