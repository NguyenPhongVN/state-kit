import Testing
import StateKit
import StateKitTesting
import Foundation

// Spec 011 US2: re-entrant dispatch from inside a QUEUED reduce must be captured
// by the drain queue, not applied directly mid-drain (where the next queued apply
// overwrites it — a lost update).

@Suite("useReducer — re-entrancy")
@MainActor
struct ReducerReentrancyTests {

    enum Action { case bump(Int) }

    @Test("dispatch from inside a queued reduce lands in the final state")
    func queuedReentrancyNotLost() {
        let h = StateTest()
        var dispatchRef: ((Action) -> Void)?

        let reduce: (inout Int, Action) -> Void = { state, action in
            switch action {
            case .bump(let n):
                state += n
                // bump(5) is queued during the initial apply (flag raised);
                // bump(7) fires from inside bump(5)'s reduce — mid-DRAIN, where
                // the flag must still protect the queue.
                if n == 5 { dispatchRef?(.bump(7)) }
                if n == 7 { dispatchRef?(.bump(3)) }
            }
        }

        var (_, dispatch) = h.render {
            useReducer(0, reduce)
        }
        dispatchRef = dispatch

        dispatch(.bump(5))

        let (final, _) = h.render {
            useReducer(0, reduce)
        }
        // 5 (initial) + 7 (queued during initial apply) + 3 (dispatched mid-drain
        // from bump(7)'s reduce). At tip the +3 is applied directly between drain
        // writes and is overwritten — final state was 12.
        #expect(final == 15, "re-entrant dispatch during the drain must land in the final state (got \(final))")
    }
}
