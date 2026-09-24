# StateKit Coding Conventions

The single rulebook for writing StateKit code. **Syntax and naming grammar follow the official
[Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)**; on
top of that sit this project's own rules (prefixes, documentation depth, force-conversion
policy), which exist to make any file navigable by any developer — including someone who has
never seen the project before.

Origins cited per rule: **[Swift]** = Swift API Design Guidelines / swift.org style,
**[Constitution]** = `.specify/memory/constitution.md` (principle number),
**[Ecosystem]** = React/Recoil/Jotai/Riverpod vocabulary this library deliberately mirrors
(see README → References & Inspiration).

Tooling enforces part of this document — see §8.

---

## 1. File layout & MARK skeleton

Every source file follows the same skeleton, in this order:

```swift
/// <One short paragraph: what lives in this file.>
///
/// <Optional: contract notes (threading, lifecycle) that apply to the whole file.>

import Foundation

// MARK: - <Main type>

public final class Example { ... }

// MARK: - Extensions

// MARK: - Internal helpers
```

- **[Swift]** clarity first; **[Constitution V]** predictable navigation is a requirement.
- A file holds ONE cohesive subject (one type, or one feature's state — see the Examples'
  `NotesFeature` pattern). If the MARK sections don't fit one subject, split the file.
- `// MARK: -` lines have a space after the dash and a title. No empty MARKs.

## 2. Naming

### 2.1 General casing and grammar — **[Swift]**

- Types `UpperCamelCase`; everything else `lowerCamelCase`.
- Functions/properties read as sentences at the call site: `container.read(p)`,
  `cache.set(key, value)`. Omit needless words (`provider.state`, not `provider.providerState`).

### 2.2 Project prefixes — **[Constitution V / Ecosystem]**

| Layer | Convention | Examples |
|-------|-----------|----------|
| Hooks (StateKit) | `use` verb prefix | `useState`, `useEffect`, `useReducer` |
| Atom machinery (StateKitAtoms) | `SK` type prefix | `SKAtomStore`, `SKState`, `SKComputed` |
| Riverpods layer | no prefix | `ProviderContainer`, `StateProvider`, `@Watch` |
| Feature modules | domain names | `TimeToLiveCache`, `RolloutManager`, `EventTracker` |

- Documented exceptions: established `*Utils` / `*Manager` names stay (`HashUtils`,
  `RolloutManager`). Do not add NEW `*Utils` names; prefer `*Helpers` + a real noun or make it
  a type with behavior.

### 2.3 Renames

Public renames ship with a migration guide entry (constitution V.5). The `SC*` → `SK*`
rename table for StateConcurrency lives in `docs/release/MIGRATION_GUIDE.md`.

## 3. Documentation (doc comments)

- **[Constitution V.4/VIII]** Every `public` symbol carries a `///` doc comment. Depth by kind:
  - **Simple accessors** (`var count: Int`): one line stating the meaning.
  - **Functions with inputs**: add `- Parameter`/`- Returns` lines when the meaning isn't
    obvious from the name.
  - **Throwing functions**: `- Throws:` naming the error cases.
  - **Stateful machinery** (stores, containers, wrappers): state the threading/isolation
    contract (`@MainActor`-confined…) and lifecycle semantics (subscribe/dispose, cleanup).
- Follow the file's dominant style; Swift documentation markup (`///`, backticked symbols,
  code fences in examples). Examples in docs MUST compile — the Examples package is the
  executable proof.
- `private`/`internal` symbols: document whenever the WHY isn't obvious. A comment that restates
  the code is noise — explain intent, constraints, and invariants instead.

## 4. Comment style

- **[Constitution V]** Comments explain WHY and the runtime cause-and-effect
  ("the setter notifies the store → dependents recompute"), never narrate syntax.
- Invariant-backed force conversions MUST carry a written justification at the site
  (see §6).
- No commented-out code. No `// TODO` without a tracking reference — the linter warns.

## 5. Concurrency annotations

- **[Constitution VI]** Stores are `@MainActor` by default. Deviations say so in the type's
  doc comment and why.
- `@unchecked Sendable` requires a written invariant note (what makes it safe).
- Long-lived background work captures its owner **weakly** and exits on release.
- `deinit`-side cleanup that hops actors must be use-after-release-safe by construction.

## 6. Errors & force conversions

- **[Constitution V.3]** Caller-reachable inputs never hit bare `as!`/`try!`/unwraps: validate
  and fail with a precise message, or throw.
- Invariant-backed conversions are allowed with a justification comment tying them to the
  guarantee (e.g. "ensureElement created this element for exactly this type").
- `fatalError` is reserved for programming errors with explanatory messages; runtime
  conditions use thrown errors.
- SwiftLint's `force_unwrapping`/`force_try`/`force_cast` run as warnings; new code must not
  add to the existing justified set.

## 7. Testing conventions

- **[Constitution VII]** Every bug fix ships red→green. Every shipped module has a test target.
- Test names state behavior: `"watch registers a reactive listener"`, not `testWatch2`.
- Leak fixes are verified with weak-reference deallocation assertions.
- Timing-sensitive tests MUST be robust under load (prefer state/polling assertions over single
  fixed sleeps) — a flaky test is a defect.

## 8. Tooling

Configs live at the repo root: `.swiftlint.yml`, `.swiftformat` (both conservative — see
comments inside). Contributor setup:

```bash
brew install swiftlint swiftformat     # once per machine
swiftlint lint --quiet                 # conventions check
swiftlint --fix                        # autocorrect the mechanical ones
swiftformat --lint .                   # formatting check
swiftformat .                          # apply formatting
```

CI/PR expectation: lint clean or violations explicitly acknowledged in review.

Documentation (DocC) builds from the doc comments — locally:

```bash
xcodebuild docbuild -scheme StateKit \
  -destination 'generic/platform=macOS' DOCC_HTML_DIR=docs-archive
```

CI/PR expectation for docs: the `docs.yml` workflow publishes the DocC archive to GitHub
Pages on every push to `main`.

## 9. Rollout & Coverage ledger

The V1 conventions pass covered all 16 modules (MARK skeleton + 100% public-symbol docs).
Per-module status is recorded below and refreshed when conventions change:

| Module | MARK skeleton | Public docs |
|--------|---------------|-------------|
| StateKitCore | ✅ | ✅ |
| StateKit | ✅ | ✅ |
| StateKitAtoms | ✅ | ✅ |
| Riverpods | ✅ | ✅ |
| StateConcurrency | ✅ | ✅ |
| StateKitPersistence | ✅ | ✅ |
| StateKitCache | ✅ | ✅ |
| StateKitAnalytics | ✅ | ✅ |
| StateKitFeatureFlags | ✅ | ✅ |
| StateKitUI | ✅ | ✅ |
| StateKitCombine | ✅ | ✅ |
| StateKitSupport | ✅ | ✅ |
| StateKitTesting | ✅ | ✅ |
| StateKitDevTools | ✅ | ✅ |
| StateKitMacros | ✅ | ✅ |
| StateKitMacrosPlugin | ✅ | ✅ (public facade; plugin internals are compiler-side) |
