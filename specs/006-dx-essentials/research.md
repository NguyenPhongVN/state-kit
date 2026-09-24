# Research: DX Essentials

Feature: specs/006-dx-essentials · Date: 2026-09-25

## D1 — focusAtom write path

**Decision**: `SKFocusAtom<Base: SKStateAtom, Field>` conforms to **`SKValueAtom`** for reads
(`value(context:) = context.watch(base)[keyPath: keyPath]` — reactive derivation, no stored
copy) and to an internal `SKFocusWriting` protocol for writes. `SKAtomStore.setStateValue`
checks the protocol first: a focus write never touches the focus's own box — it is
redirected (`_redirectWrite`) into an updated base value via `setStateValue` on the base, so
all base dependents (including the focus's own recomputer) propagate normally.

Identity: focus atoms hash/compare on `(base identity, keyPath)` so two lenses over
different fields of the same base are distinct atoms, and re-creating the same lens yields
the same store key.

**Rationale**: reads must be reactive (base changes flow in) and writes must be honest
(they land in the base — the single source of truth). This is exactly Jotai's
`focusAtom(write)` contract.

**Alternatives**: SKStateAtom conformance with an own Field box (rejected: writes would
diverge from base); returning a separate `set` closure (rejected: breaks `@SKState` binding
ergonomics).

## D2 — fileAtom

**Decision**: mirror `UserDefaultsAtom`'s structure exactly: a `FileAtomSerializable`
protocol (`fileName` + `defaultValue`, Codable+Sendable), a `FileAtomStorage<T>` class
(`load`/`save`/`delete`, falls back to default on missing/corrupt file), and a
`fileAtom(_:directory:)` factory. Storage takes a caller-provided directory so tests use
temp directories. JSON encoding via JSONEncoder/Decoder.

**Rationale**: same honest load/save pattern documented in the Start Here lessons; no
dependency; values of any size.

## D3 — ErrorBoundary evaluation timing

**Decision**: the content closure is evaluated **inside `body`** (per render pass) inside a
do/catch. Success → content; throw → `onError?(error)` then fallback(error). Because SwiftUI
re-runs `body` when the view's inputs change, a later successful render retries the content
naturally. Documented contract: catches synchronous throws from its own content closure
only; if the fallback itself throws, that error propagates.

**Rationale**: per-render evaluation gives retry-on-input-change for free and keeps the
boundary free of hidden @State bookkeeping.

## D4 — DocC publishing

**Decision**: `.github/workflows/docs.yml` — on push to `main`: checkout →
`xcodebuild docbuild -scheme StateKit -destination 'generic/platform=macOS'
DOCC_HTML_DIR=docs` → upload artifact → deploy to GitHub Pages (actions/checkout,
actions/upload-pages-artifact@v3, actions/deploy-pages@v4; `permissions: pages: write,
id-token: write`). Local command documented in the rulebook §8:
`xcodebuild docbuild -scheme StateKit -destination 'generic/platform=macOS' DOCC_HTML_DIR=docs`.
No Package.swift changes — consumers never resolve a docs plugin.

**Alternatives**: swift-docc-plugin as a package dependency (rejected: pollutes consumer
resolution for a contributor-only need).
