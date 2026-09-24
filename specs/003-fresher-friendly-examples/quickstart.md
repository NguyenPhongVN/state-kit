# Quickstart: Verify the Start Here Learning Path

Feature: specs/003-fresher-friendly-examples · Date: 2026-09-25

## 1. Regression gates

```bash
swift build && swift test          # root: zero failures (nothing in Sources/ changed)
cd Examples && swift build         # Examples package builds with the new StartHere folder
```

## 2. Roadmap-first check

Run ReferenceExamplesApp on an iOS 17+ simulator:

- Home opens with the "Start Here" section FIRST (before Macro/Module/Integration examples).
- Tapping "Start the path" opens the roadmap: 6 chapters, L01…L19 in order, each with a
  one-sentence "You will learn".
- Advanced examples appear only in their existing groups below.

## 3. Lesson walkthrough (SC-02 checklist)

> **Recorded 2026-09-25**: no iOS simulator was attached in this session, so the walkthrough was
> performed as a per-lesson code review against this checklist (compile-level correctness
> verified by `swift build`); every lesson's interaction matches its on-screen explanation per
> review. Re-run this checklist on a simulator before release.

| Lesson | Do this | Expect | Reviewed |
|--------|---------|--------|----------|
| L01 | Tap + | Count increases; on-screen text mirrors it | ✅ |
| L02 | Type in the field | The label below updates live | ✅ |
| L03 | Add / tick / delete a todo | List updates; counters match | ✅ |
| L04 | Increment on screen A, open screen B | Same count on both | ✅ |
| L05 | Change setting on screen B, go back | Screen A reflects it | ✅ |
| L06 | Change the source value | Derived label updates by itself | ✅ |
| L07 | Tap increment, then "Read again" | Displayed value changes only on re-read | ✅ |
| L08 | Tap increment | Display updates instantly; text contrasts with L07 | ✅ |
| L09 | Tap increment in the @Watch view | Updates live; text notes auto cleanup | ✅ |
| L10 | Tap Load | loading → success phases shown | ✅ |
| L11 | Toggle "fail" and Load | failure state + retry works | ✅ |
| L12 | Add/complete items | Filtered lists recompute without duplicated state | ✅ |
| L13 | Change value, kill & relaunch app | Value survived; Reset clears it | ✅ (code-verified; confirm on device) |
| L14 | Add entry, wait ~5s | Entry expires as documented | ✅ |
| L15 | Add entries past capacity | Least-recently-used evicted first | ✅ |
| L16–L17 | Read-along | One file per feature; arrows show one-way flow | ✅ |
| L18 | Read-along | The test file matches L17's provider behavior | ✅ |
| L19 Capstone | Use every control | Behaviors match earlier lessons; comments cite them | ✅ |

## 4. Originals untouched

```bash
git diff --stat -- Examples/CaseStudies/ReferenceExamplesApp/ReferenceExamples
```

Expected: no changes (only Home view + new StartHere/ folder + Package.swift).
