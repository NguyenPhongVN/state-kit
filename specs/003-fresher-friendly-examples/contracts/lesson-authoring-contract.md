# Lesson Authoring Contract

Feature: specs/003-fresher-friendly-examples · Date: 2026-09-25

Every lesson file and screen MUST follow this structure (FR-03/FR-04):

## File structure

1. **Header comment** at the top of each lesson type/struct:
   ```swift
   /// ─────────────────────────────────────────────────────────────
   /// Lesson L04 · One counter, two screens
   /// You will learn: atoms live OUTSIDE your screens, so any
   /// screen can read the same value and stay in sync.
   /// Concept count: 1 (atoms). Nothing else is new here.
   /// Next: L05 · Edit it from anywhere
   /// ─────────────────────────────────────────────────────────────
   ```
2. **Runtime comments**: every line (or tight group) that calls the library carries a
   plain-language comment describing what happens at runtime — cause and effect, not API names.
   Number the steps (1., 2., 3.) when order matters.
3. **Jargon rule**: first use of a term (re-render, binding, atom, provider, watcher, cache
   eviction…) includes a one-line plain definition; later uses rely on it.

## Screen structure (per lesson `View`)

1. `Section("What you'll learn")` — the one-sentence concept, restated on-screen.
2. `Section("Try it")` — the interactive demo (buttons/fields/lists).
3. `Section("What just happened")` — 2–4 short lines mirroring the comments, updated to reflect
   the learner's last action where practical.
4. Footer: `NavigationLink`/button "Next: L05 · Edit it from anywhere" (capstone links back to
   the roadmap).

## Style rules

- All lesson text in English (clarified). Code identifiers in English.
- One concept per lesson — if you are about to introduce a second API, stop and split.
- Demo state is in-memory unless the lesson teaches persistence (chapter 5).
- No forced unwraps, no magic numbers without a comment, screens work on any iPhone size.
