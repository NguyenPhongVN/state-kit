# Feature Specification: Fresher-Friendly Examples ("Start Here" Learning Path)

**Feature Branch**: `fresher-friendly-examples`

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description: "Rewrite the Examples package for beginner iOS engineers (freshers). Current state: 52 advanced showcase files with dense comments and no learning path — overwhelming for newcomers. Goal: a beginner 'Start Here' learning path of small, numbered, interactive lessons teaching StateKit's three core systems in order: local state (hooks), global state (atoms), Riverpod-style providers — each lesson one concept, plain-language step-by-step comments explaining WHY not just WHAT, with a capstone mini-app combining all three. Preserve the existing advanced ReferenceExamplesApp; the beginner path becomes the prominent entry point. Verify by building the Examples package."

## Clarifications

### Session 2026-09-25

- Q: Lời giải thích trong các bài học (comment + text trên màn hình) dùng ngôn ngữ nào? → A: Tiếng Anh toàn bộ (code identifiers tiếng Anh theo chuẩn); phù hợp public cho cộng đồng quốc tế trên GitHub.
- Q: Đặt lộ trình học "Start Here" ở đâu? → A: Section trong app ReferenceExamplesApp hiện có (folder riêng + Home View thêm section trên đầu, advanced giữ nguyên below). Kèm yêu cầu của user: nội dung phải ĐỦ ĐỘ, đi được từ fresher lên tới SA — không dừng ở mức fresher cơ bản.
- Q: Curriculum nên phủ đến đâu (từ fresher lên SA)? → A: Full curriculum 6 chương (~20 bài): (1) Local state cơ bản, (2) Global state với Atom, (3) Providers Riverpod, (4) Async & Derived (TaskAtom, selector, loading/error), (5) Persistence & Cache thực dụng, (6) Kiến trúc app nhỏ + final capstone. Mỗi bài vẫn 1 ý + giải thích WHY; học viên cần đâu học đó.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A fresher can see the whole learning path before writing any code (Priority: P1)

A fresher opens the examples app for the first time. Today they see 16 advanced demos with titles like "VisionOSExample" and "Nine_New_Macros_Examples" and have no idea where to begin. After this story, the app opens on a prominent "Start Here" roadmap: an ordered list of small lessons grouped into three chapters (local state → global state → providers) plus a final capstone, where each entry states in one plain sentence what the learner will understand after finishing it. Tapping an entry opens that lesson; finishing a lesson's text points to the next one.

**Why this priority**: Without a visible path, a fresher bounces off the library; every other story depends on the path existing.

**Independent Test**: Launch the app cold; verify the roadmap appears first with ordered lessons and one-sentence "you will learn" descriptions; tapping works.

**Acceptance Scenarios**:

1. **Given** a fresh launch, **When** the home screen appears, **Then** the "Start Here" roadmap is the first thing shown, above any advanced content.
2. **Given** the roadmap, **When** the learner reads any lesson entry, **Then** they see a plain-language sentence describing what they will learn, with no jargon left unexplained.
3. **Given** any lesson entry, **When** tapped, **Then** the corresponding lesson screen opens.

---

### User Story 2 - Local state lessons: the fresher learns useState by tapping (Priority: P1)

A fresher who has never seen StateKit learns local state through 3 tiny lessons: (L1) a counter — one number, one button — showing that state lives across re-renders and changing it redraws the screen; (L2) a text field — showing two-way binding with `useBinding`; (L3) a todo list — showing a list of state items with add/toggle/remove, i.e. "state is just data you transform". Every lesson screen has short step-by-step comments written in plain language, explaining what the library does behind the line (e.g. "when you tap, the value changes → SwiftUI re-runs this body → you see the new number"), not just naming the API.

**Why this priority**: Local state is the first concept every UI framework teaches; it must come before global state.

**Independent Test**: Open each lesson, interact (tap button, type text, add/toggle/remove a todo), and observe the described behavior matches the on-screen explanation.

**Acceptance Scenarios**:

1. **Given** lesson L1, **When** the learner taps the button, **Then** the number increases and the on-screen explanation matches what happened.
2. **Given** lesson L2, **When** the learner types, **Then** the text below updates live, demonstrating two-way binding.
3. **Given** lesson L3, **When** the learner adds, completes, and removes a todo, **Then** the list reflects each action and the comments explain the data transformation.

---

### User Story 3 - Global state lessons: the fresher sees data shared across screens (Priority: P1)

The learner's next question is always "OK, but that counter dies when I leave the screen — how do apps share data?". Three lessons answer with atoms: (L4) a global counter read from two different screens showing both stay in sync; (L5) the same atom edited from a second screen (settings-style); (L6) a derived atom — a value computed from another atom (e.g. a doubled count or a formatted label) that updates automatically. Comments explain the mental model shift: "atoms live outside the screen; screens subscribe".

**Why this priority**: Global state is StateKit's reason to exist; it must be taught immediately after local state with a visible before/after contrast.

**Independent Test**: Open lesson L4/L5, change the shared value on one screen, navigate to the other screen and verify it shows the same updated value; L6 shows the derived value update without manual refresh.

**Acceptance Scenarios**:

1. **Given** lesson L4, **When** the learner increments the counter on screen A then navigates to screen B, **Then** screen B shows the same count.
2. **Given** lesson L5, **When** the learner edits a shared setting on the settings screen, **Then** returning to the main screen reflects the change immediately.
3. **Given** lesson L6, **When** the learner changes the source atom, **Then** the derived value (computed from it) updates with no extra code in the lesson.

---

### User Story 4 - Provider lessons: the fresher learns Riverpod-style state (Priority: P2)

Three lessons teach the provider system with the same "tap and see" style: (L7) a StateProvider counter with `read` — one-shot fetch for display; (L8) the same provider with `watch` — the screen updates live, and the comments call out the read-vs-watch difference explicitly (this library now teaches it as Riverpod does); (L9) `@Watch` in a plain SwiftUI view — showing the property-wrapper form and that listeners are removed automatically when the view disappears.

**Why this priority**: The provider system is the third core pillar; teaching read-vs-watch here reinforces the semantics documented in feature 002.

**Independent Test**: L7 increments do not update the displayed value until re-read; L8 updates live; L9's view updates and the lesson text explains cleanup.

**Acceptance Scenarios**:

1. **Given** lesson L7, **When** the learner taps increment, **Then** the fetched-once number does NOT change until they tap a "read again" control — and the text explains why.
2. **Given** lesson L8, **When** the learner taps increment, **Then** the number updates immediately — and the text explains the difference from L7.
3. **Given** lesson L9, **When** the learner taps increment, **Then** the `@Watch`-backed view updates, and the comments note automatic listener cleanup.

---

### User Story 5 - Capstone: one tiny app using all three systems (Priority: P2)

The learner proves understanding by reading one small, complete app: a study-timer / shopping-list style mini app (kept deliberately small) that uses local state for a screen-private value, an atom for the shared value, a provider for it, and one derived/computed display — with comments marking which system each piece uses and why. The capstone has no new API: everything in it was taught in L1–L9.

**Why this priority**: Consolidation; only valuable once the chapters exist.

**Independent Test**: Read the capstone end-to-end; every construct maps back to a numbered lesson (comments cite the lesson numbers).

**Acceptance Scenarios**:

1. **Given** the capstone screen, **When** the learner uses the app (interact with each control), **Then** all behavior matches what earlier lessons taught, with no unexplained new API.
2. **Given** the capstone source, **When** the learner reads a piece of state, **Then** a comment names the system it uses and cites the lesson that taught it.

---

### User Story 6 - Advanced content stays available but never blocks a beginner (Priority: P3)

The existing advanced examples remain fully functional (repo convention: originals preserved) but are visually separated below the roadmap under an explicit "Advanced reference" grouping, so a fresher is never funneled into them by accident.

**Why this priority**: Safety net for scope; zero new behavior.

**Independent Test**: Verify all pre-existing advanced examples still open and build, and appear only after the roadmap section.

**Acceptance Scenarios**:

1. **Given** the home screen, **When** the learner scrolls past the roadmap, **Then** they find the advanced examples grouped under a clearly-labeled advanced section.
2. **Given** any pre-existing advanced example, **When** opened, **Then** it behaves exactly as before this feature.

---

### User Story 7 - Intermediate and advanced chapters carry the learner to professional level (Priority: P2)

After the three core chapters, the learner continues through chapters 4–6 so the path genuinely reaches senior/architect-level usage: chapter 4 teaches async and derived state (loading a value over time with task atoms, showing loading/error states, computing values from other state); chapter 5 teaches practical persistence and caching (surviving relaunch, cache with expiry); chapter 6 teaches small-app architecture (organizing state by feature, one-screen-per-concern, dependency direction) and closes with a final capstone mini-app that combines everything. Each lesson keeps the one-concept rule, and every chapter uses only APIs taught in previous chapters plus its own new ones — no surprise API appears without its lesson.

**Why this priority**: This is the clarified completeness requirement (fresher → SA); it extends reach but rides on the same lesson mechanics as US2–US4.

**Independent Test**: Walk chapters 4–6 in order; each new API appears first in its own lesson; the final capstone uses only previously-taught constructs.

**Acceptance Scenarios**:

1. **Given** a chapter-4 lesson, **When** the learner runs it, **Then** they see loading/error/success states (or a derived value) exactly as the on-screen explanation describes.
2. **Given** a chapter-5 lesson, **When** the learner relaunches the lesson, **Then** the persisted value survives (or the cached value expires as documented).
3. **Given** the chapter-6 capstone, **When** the learner reads its source, **Then** every construct cites an earlier lesson and no unexplained API appears.

### Edge Cases

- What happens when a fresher taps lessons out of order? (Every lesson is self-contained and still works; each screen repeats its one-sentence concept so order is recommended, not required.)
- What happens when the app relaunches mid-path? (Lessons are stateless except their demo state; roadmap position is just a list — no progress tracking is required.)
- What happens when a lesson's explanation references a word a fresher may not know (e.g. "re-render")? (First use of each term links its plain-language explanation; jargon is introduced once and reused.)
- What happens when the advanced examples change later? (The roadmap must not depend on any advanced file — it compiles and runs independently.)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-01**: The app MUST open on an ordered "Start Here" roadmap above all advanced content, with one plain-language "you will learn" sentence per lesson.
- **FR-02**: The path MUST contain six progressive chapters (~20 entries total) — (1) local state basics, (2) global state with atoms, (3) Riverpod-style providers, (4) async & derived state (task atoms, selectors, loading/error handling), (5) practical persistence & caching, (6) small-app architecture + a final capstone — enough to carry a learner from fresher to senior/architect-level usage of the library.
- **FR-03**: Each lesson MUST be one small self-contained screen demonstrating exactly one concept, interactive (the learner performs an action and sees the described result).
- **FR-04**: Each lesson's source MUST explain step-by-step in plain language what the library does behind the scenes (the WHY), not just name the API; the first use of any technical term carries its plain-language explanation.
- **FR-05**: Every lesson MUST end by pointing to the next lesson (and the capstone MUST close the loop back to the roadmap).
- **FR-06**: Progression rule: every lesson uses only APIs taught in earlier lessons plus the single new concept it introduces; the final capstone uses only previously-taught constructs. Chapters 1–3 stay within the three core systems; chapters 4–6 progressively introduce async/derived, persistence/cache, and architecture topics.
- **FR-07**: Pre-existing advanced examples MUST remain present, functional, and unchanged, grouped under an explicitly-labeled advanced section below the roadmap.
- **FR-08**: The Examples package MUST build successfully after the change; the roadmap MUST NOT depend on any advanced example file.
- **FR-09**: Lesson text language follows the clarified decision (see Clarifications section when present); code identifiers stay in English per platform convention.
- **FR-10**: All existing test suites MUST remain green after the change (examples are app code — no new unit tests required; the build plus manual lesson walkthrough is the acceptance gate).

### Key Entities *(include if feature involves data)*

- **Lesson**: numbered entry with a title, a one-sentence "you will learn" description, one demo screen, and a next-lesson pointer.
- **Chapter**: group of three lessons sharing one mental model (local / global / provider).
- **Roadmap**: the ordered, first-seen list of chapters, lessons, and the capstone.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-01**: A learner following the roadmap from cold launch reaches the final capstone without needing any file outside the lesson set (all roadmap entries open and run).
- **SC-02**: Every lesson is interactive with behavior matching its on-screen explanation (manual walkthrough checklist in quickstart).
- **SC-03**: 100% of lesson source files explain the why behind each line that uses the library (spot-check: no library call without a surrounding plain-language comment).
- **SC-04**: 0 changes to pre-existing advanced example files (verified by diff — only the home view gains the roadmap section).
- **SC-05**: The Examples package builds with zero errors; the root package's full test suite remains green.

## Assumptions

- The learning path is added inside the existing ReferenceExamplesApp executable as a new, self-contained folder plus a home-screen section — preserving the repo's originals-preserved convention (confirmed in clarify).
- ~20 lessons across 6 chapters is the agreed size (confirmed in clarify); final per-lesson titles are a planning detail.
- All lesson text is English (confirmed in clarify).
- Lesson demo state is in-memory by default; chapter 5's persistence lessons are the deliberate exception (their whole point is surviving relaunch) and use only the persistence APIs taught in that chapter.
- Comments' explanation depth targets a reader who knows Swift basics (let/var, closures, structs) but has never used StateKit; SwiftUI basics are briefly re-explained where they interact with the library.
