import Testing
import StateKit
@testable import StateKitAtoms

@MainActor
@Suite("SKAtomStore — TaskAtom")
struct SKAtomStoreTaskTests {

    @Test("task atom starts with loading phase")
    func taskAtomStartsLoading() {
        let store = SKAtomStore()
        #expect(store.taskBox(for: FetchAtom()).value.isLoading)
    }

    @Test("task atom transitions to success")
    func taskAtomSuccess() async {
        let store = SKAtomStore()
        _ = store.taskBox(for: FetchAtom())

        try? await Task.sleep(nanoseconds: 100_000_000)

        let box: SKAtomBox<AsyncPhase<String>>? = store.existingBox(for: SKAtomKey(FetchAtom()))
        #expect(box?.value.value == "fetched")
    }

    @Test("throwing task atom transitions to failure")
    func throwingTaskAtomFailure() async {
        let store = SKAtomStore()
        _ = store.throwingTaskBox(for: FailingAtom())

        try? await Task.sleep(nanoseconds: 100_000_000)

        let box: SKAtomBox<AsyncPhase<String>>? = store.existingBox(for: SKAtomKey(FailingAtom()))
        #expect(box?.value.isFailure == true)
    }

    @Test("restartTask launches a new request")
    func restartTaskLaunchesNewRequest() async {
        let store = SKAtomStore()
        let source = ControlledTaskSource()
        let atom = ControlledRefreshAtom(source: source)
        let box = store.taskBox(for: atom)

        await Task.yield()
        source.resolve(source.pendingRequestIDs[0], with: "initial")
        await Task.yield()

        store.restartTask(for: atom)
        #expect(box.value.isLoading)
        await waitUntil(source.pendingRequestIDs.count == 1)

        let requestID = source.pendingRequestIDs[0]
        source.resolve(requestID, with: "restarted")
        await Task.yield()

        #expect(box.value.value == "restarted")
    }

    @Test("restartThrowingTask launches a new request")
    func restartThrowingTaskLaunchesNewRequest() async {
        let store = SKAtomStore()
        let source = ControlledThrowingTaskSource()
        let atom = ControlledThrowingRefreshAtom(source: source)
        let box = store.throwingTaskBox(for: atom)

        await Task.yield()
        source.resolve(source.pendingRequestIDs[0], with: "initial")
        await Task.yield()

        store.restartThrowingTask(for: atom)
        #expect(box.value.isLoading)
        await waitUntil(source.pendingRequestIDs.count == 1)

        let requestID = source.pendingRequestIDs[0]
        source.resolve(requestID, with: "restarted")
        await Task.yield()

        #expect(box.value.value == "restarted")
    }

    @Test("refreshTask cancels prior manual refresh and keeps latest result")
    func refreshTaskKeepsLatestResult() async {
        let store = SKAtomStore()
        let source = ControlledTaskSource()
        let atom = ControlledRefreshAtom(source: source)

        _ = store.taskBox(for: atom)
        await Task.yield()
        source.resolve(source.pendingRequestIDs[0], with: "initial")
        await Task.yield()

        let refresh1 = Task { @MainActor in
            await store.refreshTask(for: atom)
        }
        await waitUntil(source.pendingRequestIDs.count == 1)

        let refresh2 = Task { @MainActor in
            await store.refreshTask(for: atom)
        }
        await waitUntil(source.pendingRequestIDs.count == 2)

        let requestIDs = source.pendingRequestIDs
        #expect(requestIDs.count == 2)

        source.resolve(requestIDs[1], with: "fresh")
        await Task.yield()
        source.resolve(requestIDs[0], with: "stale")

        await refresh1.value
        await refresh2.value

        let box: SKAtomBox<AsyncPhase<String>>? = store.existingBox(for: SKAtomKey(atom))
        #expect(box?.value.value == "fresh")
    }

    @Test("refreshThrowingTask cancels prior manual refresh and keeps latest result")
    func refreshThrowingTaskKeepsLatestResult() async {
        let store = SKAtomStore()
        let source = ControlledThrowingTaskSource()
        let atom = ControlledThrowingRefreshAtom(source: source)

        _ = store.throwingTaskBox(for: atom)
        await Task.yield()
        source.resolve(source.pendingRequestIDs[0], with: "initial")
        await Task.yield()

        let refresh1 = Task { @MainActor in
            await store.refreshThrowingTask(for: atom)
        }
        await waitUntil(source.pendingRequestIDs.count == 1)

        let refresh2 = Task { @MainActor in
            await store.refreshThrowingTask(for: atom)
        }
        await waitUntil(source.pendingRequestIDs.count == 2)

        let requestIDs = source.pendingRequestIDs
        #expect(requestIDs.count == 2)

        source.resolve(requestIDs[1], with: "fresh")
        await Task.yield()
        source.fail(requestIDs[0], with: ControlledRefreshError())

        await refresh1.value
        await refresh2.value

        let box: SKAtomBox<AsyncPhase<String>>? = store.existingBox(for: SKAtomKey(atom))
        #expect(box?.value.value == "fresh")
    }
}
