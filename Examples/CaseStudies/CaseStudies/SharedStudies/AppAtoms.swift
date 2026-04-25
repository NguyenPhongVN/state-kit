import Foundation
import StateKitAtoms

struct CounterAtom: SKStateAtom, Hashable {
    typealias Value = Int

    func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
}

struct NameAtom: SKStateAtom, Hashable {
    typealias Value = String

    func defaultValue(context: SKAtomTransactionContext) -> String { "Alice" }
}

struct RequestSeedAtom: SKStateAtom, Hashable {
    typealias Value = Int

    func defaultValue(context: SKAtomTransactionContext) -> Int { 1 }
}

struct RequestShouldFailAtom: SKStateAtom, Hashable {
    typealias Value = Bool

    func defaultValue(context: SKAtomTransactionContext) -> Bool { false }
}

struct DoubledCounterAtom: SKValueAtom, Hashable {
    typealias Value = Int

    func value(context: SKAtomTransactionContext) -> Int {
        context.watch(CounterAtom()) * 2
    }
}

struct FormattedAtom: SKValueAtom, Hashable {
    typealias Value = String

    func value(context: SKAtomTransactionContext) -> String {
        "\(context.watch(NameAtom())): \(context.watch(CounterAtom()))"
    }
}

struct FetchAtom: SKTaskAtom, Hashable {
    typealias TaskSuccess = String

    func task(context: SKAtomTransactionContext) async -> String {
        let requestID = context.watch(RequestSeedAtom())
        let name = context.watch(NameAtom())
        let count = context.watch(CounterAtom())

        try? await Task.sleep(nanoseconds: 600_000_000)
        return "Synced request #\(requestID) for \(name) with count \(count)"
    }
}

enum DemoFetchError: LocalizedError {
    case rejected(Int)

    var errorDescription: String? {
        switch self {
        case .rejected(let requestID):
            return "Request #\(requestID) was rejected to demo the failure phase."
        }
    }
}

struct FailingAtom: SKThrowingTaskAtom, Hashable {
    typealias TaskSuccess = String

    func task(context: SKAtomTransactionContext) async throws -> String {
        let requestID = context.watch(RequestSeedAtom())
        let shouldFail = context.watch(RequestShouldFailAtom())

        try await Task.sleep(nanoseconds: 700_000_000)

        if shouldFail {
            throw DemoFetchError.rejected(requestID)
        }

        return "Profile #\(requestID) loaded"
    }
}

let inlineCounterAtom = atom(3)
let inlineNameAtom = atom("Inline atom")
let inlineSummaryAtom = selector { context in
    "\(context.watch(inlineNameAtom)) x\(context.watch(inlineCounterAtom))"
}

let memberScoreAtom = atomFamily { (id: Int) in
    id * 10
}

let memberLabelAtom = selectorFamily { (id: Int, context: SKAtomTransactionContext) in
    let score = context.watch(memberScoreAtom(id))
    return "Member \(id) has score \(score)"
}

let scopedCounterAtom = atom(0)
