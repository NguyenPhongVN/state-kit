import SwiftUI
import StateKit
import StateKitAtoms
import StateKitUI
import StateKitCache
import Riverpods

// ═══════════════════════════════════════════════════════════════════
//  CHAPTER 5 · PERSISTENCE & CACHE
//
//  Everything so far died when the app died. This chapter: state that
//  SURVIVES a relaunch (UserDefaults-backed atoms) and caches that
//  manage their own memory (TTL expiry, LRU capacity).
// ═══════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────
// Lesson L13 · Survive a relaunch
//
// You will learn: persisted state = load at start + save on change.
// `userDefaultsAtom` gives you the "load" half; the lesson shows the
// honest "save" half explicitly, so nothing feels like magic.
// ─────────────────────────────────────────────────────────────────

// 1. Describe WHAT gets persisted: the key it lives under and the
//    value to use when nothing is stored yet. (Codable does the rest.)
private struct StudyMinutes: UserDefaultsSerializable, Codable, Sendable {
    static let userDefaultsKey = "starthere.studyMinutes"
    static let defaultValue = StudyMinutes(total: 0)
    var total: Int
}

// 2. The "load at start" half: reading this atom's default pulls the
//    stored value (or the default above on first launch).
private let studyMinutesLoader = userDefaultsAtom(StudyMinutes.self)

private enum StudyMinutesStore {
    static func save(_ value: StudyMinutes) {
        // 3. The "save on change" half: encode and store under the SAME key
        //    the loader reads. Load + save under one key = persistence.
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: StudyMinutes.userDefaultsKey)
        }
    }
}

private let studyMinutesProvider = StateProvider { _ in studyMinutesLoader().total }

struct Lesson13PersistedAtom: View {
    @Watch(studyMinutesProvider) private var minutes
    @Environment(\.providerContainer) private var container

    var body: some View {
        Form {
            Section("What you'll learn") {
                Text("This counter is saved to UserDefaults. Kill the app and reopen it (or relaunch from Xcode) — the number is still here.")
            }
            Section("Try it") {
                LabeledContent("Total study minutes", value: "\(minutes)")

                Button("+10 minutes") {
                    let next = minutes + 10
                    container.read(studyMinutesProvider.notifier).state = next
                    StudyMinutesStore.save(StudyMinutes(total: next))
                }
                .buttonStyle(.borderedProminent)

                Button("Reset (for practicing this lesson)") {
                    container.read(studyMinutesProvider.notifier).state = 0
                    StudyMinutesStore.save(StudyMinutes(total: 0))
                }
            }
            Section("What just happened") {
                Text("Start = load from storage; every change = write to storage. Real apps wrap that pattern once and forget it — now you know exactly what it does.")
                    .font(.footnote)
            }
            StartHereNextButton(current: .persistedAtom)
        }
        .navigationTitle("L13 · Persisted")
    }
}

// ─────────────────────────────────────────────────────────────────
// Lesson L14 · Expire after a while
//
// You will learn: a TTL cache keeps entries only for their lifetime.
// This lesson uses a 5-second TTL so you can WATCH an entry expire —
// the same idea, scaled up, backs real image/response caches.
// ─────────────────────────────────────────────────────────────────
struct Lesson14TTLCache: View {
    // 1. A cache: string keys, string values, entries live 5 seconds.
    //    (MainActor because UI code uses it directly here.)
    @State private var cache = TimeToLiveCache<String, String>(ttl: 5)
    @State private var status = "Put a key, then try to get it before 5s pass."

    var body: some View {
        Form {
            Section("What you'll learn") {
                Text("TTL = time to live. Put an entry, wait, and it is gone — no cron job, no manual cleanup, the cache does it.")
            }
            Section("Try it") {
                Button("Put \"token\" (fresh for 5s)") {
                    cache.set("token", "abc123")
                    status = "Stored at \(Date().formatted(date: .omitted, time: .standard)). Try to get it within 5 seconds…"
                }
                Button("Get \"token\"") {
                    // 2. get returns nil for missing AND expired entries —
                    //    callers treat both the same: "fetch it again".
                    if let value = cache.get("token") {
                        status = "Got: \(value) (still alive)"
                    } else {
                        status = "Gone — it expired or never existed. That's TTL working."
                    }
                }
                LabeledContent("Status", value: status)
            }
            Section("What just happened") {
                Text("After ~5 seconds the entry dies by itself. The cache even runs cleanup on a background schedule — you never call it.")
                    .font(.footnote)
            }
            StartHereNextButton(current: .ttlCache)
        }
        .navigationTitle("L14 · TTL cache")
    }
}

// ─────────────────────────────────────────────────────────────────
// Lesson L15 · Forget the least used
//
// You will learn: an LRU cache has a CAPACITY instead of a lifetime.
// When it is full, the LEAST RECENTLY USED entry is evicted. "Used"
// includes reading — so `get` refreshes an entry's freshness too.
// ─────────────────────────────────────────────────────────────────
struct Lesson15LRUCache: View {
    // 1. Only 3 entries fit. The 4th insert evicts whoever you touched longest ago.
    @State private var cache = LeastRecentlyUsedCache<String, Int>(capacity: 3)

    var body: some View {
        Form {
            Section("What you'll learn") {
                Text("Capacity 3. Insert A, B, C — then insert D: A is evicted (least recently used). But `get` refreshes: read A before inserting D, and B is evicted instead.")
            }
            Section("Try it") {
                HStack {
                    Button("put A=1") { cache.set("A", 1) }
                    Button("put B=2") { cache.set("B", 2) }
                    Button("put C=3") { cache.set("C", 3) }
                }
                HStack {
                    Button("put D=4 (evicts someone)") { cache.set("D", 4) }
                        .buttonStyle(.borderedProminent)
                }
                HStack {
                    Button("get A (refreshes A)") { _ = cache.get("A") }
                    Button("get B") { _ = cache.get("B") }
                    Button("get C") { _ = cache.get("C") }
                }

                // 2. `keys` shows the order: first = next to be evicted,
                //    last = most recently used (or inserted).
                let order = cache.keys
                LabeledContent("Order (first = next evicted)", value: order.isEmpty ? "—" : order.joined(separator: " → "))
            }
            Section("What just happened") {
                Text("Watch the order line: every put/get moves a key to the END of the line. When a 4th entry arrives, the START of the line is evicted. Fixed memory, predictable victim.")
                    .font(.footnote)
            }
            StartHereNextButton(current: .lruCache)
        }
        .navigationTitle("L15 · LRU cache")
    }
}
