# Data Model: Health Bundle

Feature: specs/005-health-bundle · Date: 2026-09-25

## ReplayReport (StateKitDevTools)
- `executed: [String]` — actions the handler accepted, in order.
- `skipped: [String]` — actions the handler rejected (or entries without actions).
- `failure: Error?` — non-nil when the handler threw; replay stopped at that entry.

## LRU Node (internal, StateKitCache)
- `key: Key`, `value: Value`, `prev: Node?`, `next: Node?`
- Invariants: `head` = most recent; `tail` = least recent; `cache.count == list count`;
  eviction always from `tail`; `keys` derived by walking head→tail reversed (oldest→newest).

## CI workflow
- Job `test`: checkout → `swift build` → `swift test` → Examples `swift build`.
- Job `lint`: checkout → install SwiftLint → `swiftlint lint --quiet` (`continue-on-error: true`).
