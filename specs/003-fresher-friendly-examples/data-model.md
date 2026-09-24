# Data Model: The Lesson Catalog (definitive)

Feature: specs/003-fresher-friendly-examples · Date: 2026-09-25

## Entities

- **Lesson**: id (L01…L19), title, one-sentence "You will learn", concept (single), file, "Next" pointer.
- **Chapter**: number, title, theme, ordered lessons.
- **Roadmap**: ordered chapters + lessons; rendered by the roadmap screen; first section on home.

## Catalog

### Chapter 1 — Local state with hooks (`Chapter1_LocalState.swift`)
| ID | Title | One new concept |
|----|-------|-----------------|
| L01 | Your first counter | `useState` — state that survives re-renders |
| L02 | A field that listens | `useBinding` — two-way binding to controls |
| L03 | A tiny todo list | State as data — add / toggle / remove items |

### Chapter 2 — Global state with atoms (`Chapter2_GlobalState.swift`)
| ID | Title | One new concept |
|----|-------|-----------------|
| L04 | One counter, two screens | `@StateAtom` + `@SKState` — state living outside screens |
| L05 | Edit it from anywhere | Writing the same atom from a second (settings) screen |
| L06 | Values that compute themselves | Derived atom (`@Computed`) — no manual refresh |

### Chapter 3 — Riverpod-style providers (`Chapter3_Providers.swift`)
| ID | Title | One new concept |
|----|-------|-----------------|
| L07 | Read once | `StateProvider` + `container.read` — a one-shot look |
| L08 | Watch it live | `container.watch` — and the honest read-vs-watch difference |
| L09 | The SwiftUI wrapper | `@Watch` — reactive property, automatic listener cleanup |

### Chapter 4 — Async & derived (`Chapter4_AsyncDerived.swift`)
| ID | Title | One new concept |
|----|-------|-----------------|
| L10 | Loading… then data | `@TaskAtom` — async state with `loading/success` phases |
| L11 | When things fail | `@ThrowingTaskAtom` — surfacing `failure` with retry |
| L12 | Filter without duplicating | selector-style derived list (completed vs active todos) |

### Chapter 5 — Persistence & cache (`Chapter5_PersistenceCache.swift`)
| ID | Title | One new concept |
|----|-------|-----------------|
| L13 | Survive a relaunch | `userDefaultsAtom` — persisted atom + reset button |
| L14 | Expire after a while | `TimeToLiveCache` — entries that age out (observable in seconds) |
| L15 | Forget the least used | `LeastRecentlyUsedCache` — capacity-driven eviction |

### Chapter 6 — Architecture + capstone (`Chapter6_Architecture.swift`, `Capstone_StudyTracker.swift`)
| ID | Title | One new concept |
|----|-------|-----------------|
| L16 | One feature, one home | Grouping an atom + provider per feature file |
| L17 | Data flows in one direction | Screen → action → state → UI (no back-channels) |
| L18 | Prove it works | Reading a unit test for L17's provider (read-along lesson) |
| L19 | Capstone: Study Tracker | Combining L01–L18 in one small app |

## Rules

- Order is the teaching order; the catalog is the single source of truth for the roadmap UI.
- Progression: a lesson's code may only use earlier lessons' APIs plus its "one new concept".
- The capstone introduces nothing new.
