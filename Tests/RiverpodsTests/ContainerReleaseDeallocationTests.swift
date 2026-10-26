import Testing
import Foundation
import StateKitAtoms
@testable import Riverpods

// Spec 009 US1: releasing a provider container deallocates the container and
// every element it holds — including elements abandoned mid-work or never
// listened to. Previously the element's strong container back-reference
// (element → container → elements dict → element) pinned both objects.

@MainActor
@Suite("Container Release Deallocation — 009 US1")
struct ContainerReleaseDeallocationTests {

    @Test("releasing the container deallocates it and all elements")
    func containerReleaseDeallocatesAll() async throws {
        weak var weakContainer: AnyObject?
        weak var weakStateElement: AnyObject?
        weak var weakUnlistenedElement: AnyObject?

        do {
            let container = ProviderContainer()
            weakContainer = container

            let listened = StateProvider { _ in 1 }
            let unlistened = FutureProvider { _ -> Int in
                try await Task.sleep(nanoseconds: 30_000_000)
                return 7
            }

            _ = container.watch(listened)  // listened element
            weakStateElement = container.ensureElement(for: listened)

            // Unlistened element with in-flight work.
            let unlistenedElement = container.ensureElement(for: unlistened)
            _ = container.read(unlistened)
            weakUnlistenedElement = unlistenedElement
        }

        // Give the in-flight fetch a moment, then drain.
        try await Task.sleep(for: .milliseconds(100))
        for _ in 0..<100 where weakContainer != nil || weakStateElement != nil || weakUnlistenedElement != nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(weakContainer == nil, "container leaked: its elements retain it")
        #expect(weakStateElement == nil, "listened element leaked with the container")
        #expect(weakUnlistenedElement == nil,
                "unlistened element leaked: its strong container back-reference pinned both")
    }

    @Test("async work with a released container exits without notifying")
    func asyncWorkSurvivesReleasedContainer() async throws {
        weak var weakElement: AnyObject?

        do {
            let container = ProviderContainer()
            let provider = FutureProvider { _ -> Int in
                try await Task.sleep(nanoseconds: 200_000_000)
                return 7
            }
            let element = container.ensureElement(for: provider)
            _ = container.read(provider)  // starts the fetch
            weakElement = element
        } // container released while the fetch is still in flight

        // The fetch completes into a dead graph: no crash, no notify, and the
        // element (retained only by its work frame) deallocates afterwards.
        try await Task.sleep(for: .milliseconds(400))
        for _ in 0..<100 where weakElement != nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(weakElement == nil, "element leaked after its container was released mid-work")
    }
}
