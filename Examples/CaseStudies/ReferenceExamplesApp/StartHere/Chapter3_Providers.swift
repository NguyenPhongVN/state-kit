import SwiftUI
import Riverpods

// ═══════════════════════════════════════════════════════════════════
//  CHAPTER 3 · RIVERPOD-STYLE PROVIDERS
//
//  Providers are the third way to hold state: like atoms they live in
//  a container outside views, but they are created from a BUILD
//  function (so they can compute their first value, watch other
//  providers, and be swapped in tests). The key skill of this chapter
//  is the honest difference between READ and WATCH.
// ═══════════════════════════════════════════════════════════════════

// 1. One provider for the whole chapter: builds its starting value as
//    0. `notifier` (used below) is how you change a StateProvider's
//    value: `container.read(p.notifier).state = <new value>`.
enum StartHereProviders {
    static let counter = StateProvider { _ in 0 }
}

// ─────────────────────────────────────────────────────────────────
// Lesson L07 · Read once
//
// You will learn: `read` is a SNAPSHOT. It asks "what is the value
// right now?" and hands you a copy. It does not sign you up for
// future changes — so this screen's number goes stale on purpose.
// ─────────────────────────────────────────────────────────────────
struct Lesson07ProviderRead: View {
    @Environment(\.providerContainer) private var container

    // 2. A plain @State copy. This is what `read` fills: a photograph of
    //    the value at the moment you asked.
    @State private var snapshot = 0

    var body: some View {
        Form {
            Section("What you'll learn") {
                Text("`read` = \"tell me NOW\". It will not update this screen when the value changes — watch what that means.")
            }
            Section("Try it") {
                LabeledContent("Snapshot taken earlier", value: "\(snapshot)")

                Button("Increment the provider") {
                    // 3. Writing: every StateProvider carries a `notifier`
                    //    whose `state` you can set. Note: this button does
                    //    NOT update the snapshot above!
                    container.read(StartHereProviders.counter.notifier).state += 1
                }
                .buttonStyle(.borderedProminent)

                Button("Read again") {
                    // 4. Only an explicit re-read refreshes the snapshot.
                    snapshot = container.read(StartHereProviders.counter)
                }
            }
            Section("What just happened") {
                Text("Tap \"Increment\" a few times: the provider's real value grows, your snapshot stays frozen until you press \"Read again\". If a screen needs to react to changes, that's WATCH — next lesson.")
                    .font(.footnote)
            }
            StartHereNextButton(current: .providerRead)
        }
        .navigationTitle("L07 · Read")
        .onAppear {
            // 5. First read — the provider builds its value on first access.
            snapshot = container.read(StartHereProviders.counter)
        }
    }
}

// ─────────────────────────────────────────────────────────────────
// Lesson L08 · Watch it live
//
// You will learn: `watch` registers interest. Reading a provider's
// value through watch (or subscribing to it) means "keep me posted".
// This screen holds a LIVE connection next to the stale snapshot from
// L07, so you can feel the difference.
// ─────────────────────────────────────────────────────────────────
struct Lesson08ProviderWatch: View {
    @Environment(\.providerContainer) private var container

    // The live value, updated by our subscription.
    @State private var live = 0
    // The subscription object: as long as you keep it, updates keep
    // coming. Closing it stops the updates (and lets auto-dispose clean up).
    @State private var subscription: ProviderSubscription?

    var body: some View {
        Form {
            Section("What you'll learn") {
                Text("`watch`/`listen` = \"keep me posted\". Same provider as L07, but now the screen has registered interest.")
            }
            Section("Try it") {
                LabeledContent("Live value (subscribed)", value: "\(live)")

                Button("Increment the provider") {
                    container.read(StartHereProviders.counter.notifier).state += 1
                }
                .buttonStyle(.borderedProminent)
            }
            Section("What just happened") {
                Text("One tap → live value moves immediately, no re-read needed. L07's snapshot needed a button press; this screen SUBSCRIBED, so changes find it.")
                    .font(.footnote)
            }
            StartHereNextButton(current: .providerWatch)
        }
        .navigationTitle("L08 · Watch")
        .onAppear {
            // 1. `watch` marks the provider as in-use (this matters for
            //    auto-dispose providers: being watched keeps them alive).
            live = container.watch(StartHereProviders.counter)
            // 2. `listen` delivers every change as a callback. It hands us a
            //    subscription; keeping it alive keeps the updates flowing.
            subscription = container.listen(StartHereProviders.counter) { _, newValue in
                live = newValue
            }
        }
        .onDisappear {
            // 3. Always close what you opened. Closing removes the listener —
            //    unbalanced watches/listens keep providers alive forever.
            subscription?.close()
        }
    }
}

// ─────────────────────────────────────────────────────────────────
// Lesson L09 · The SwiftUI wrapper
//
// You will learn: `@Watch` = live state as a property. The wrapper
// subscribes for you when the view appears and unsubscribes when the
// view disappears. You read `count` like a plain variable.
// ─────────────────────────────────────────────────────────────────
struct Lesson09WatchWrapper: View {
    // 1. One line replaces onAppear/onDisappear bookkeeping from L08:
    //    @Watch watches the provider while this view is alive.
    @Watch(StartHereProviders.counter) private var count

    @Environment(\.providerContainer) private var container

    var body: some View {
        Form {
            Section("What you'll learn") {
                Text("The property-wrapper form of watching: reactive value, automatic subscribe/unsubscribe, zero callbacks in your code.")
            }
            Section("Try it") {
                LabeledContent("Count via @Watch", value: "\(count)")

                Button("Increment") {
                    container.read(StartHereProviders.counter.notifier).state += 1
                }
                .buttonStyle(.borderedProminent)
            }
            Section("What just happened") {
                Text("The label updates on every tap with no onChange and no re-read. When this screen disappears, @Watch releases the listener by itself — that cleanup is the part beginners forget, so the library does it for you.")
                    .font(.footnote)
            }
            StartHereNextButton(current: .watchWrapper)
        }
        .navigationTitle("L09 · @Watch")
    }
}
