import Testing
import StateKit
import StateKitTesting
import Combine
import Observation
import Foundation

// Regression suite for spec 008 US2: publisher hooks must never write hook
// state off the main actor, no matter which scheduler the upstream emits on.
//
// Detection mechanism: Observation's onChange handler is invoked on the thread
// that performs the mutation. We track the hook's phase signal through a
// re-render (the hook reads its signal on every render) and record
// `Thread.isMainThread` from the change handler.

/// Thread-safe recorder for the main-thread flag of each observed write.
final class WriteRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var flags: [Bool] = []

    func record(onMain: Bool) {
        lock.lock()
        flags.append(onMain)
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return flags.count
    }

    var allOnMain: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !flags.isEmpty && flags.allSatisfy { $0 }
    }
}

/// Re-registers observation tracking after every observed write so successive
/// phase mutations are all recorded. `read` performs one render pass that
/// reads the hook's phase signal (registering the observation).
@MainActor
final class PhaseWriteTracker {
    let recorder = WriteRecorder()
    private let read: @MainActor () -> Void

    init(read: @escaping @MainActor () -> Void) {
        self.read = read
    }

    func register() {
        withObservationTracking {
            read()
        } onChange: { [weak self] in
            guard let self else { return }
            recorder.record(onMain: Thread.isMainThread)
            Task { @MainActor [weak self] in
                self?.register()
            }
        }
    }

    /// Waits until `expected` writes have been observed (or times out).
    func waitForWrites(_ expected: Int) async throws {
        let deadline = Date().addingTimeInterval(5)
        while recorder.count < expected && Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

@MainActor
@Suite("Publisher Hook Main-Thread Writes — P1 fixes")
struct PublisherHookMainThreadTests {

    @Test("usePublisher phase writes land on the main actor")
    func usePublisherWritesOnMain() async throws {
        let h = StateTest()
        let subject = PassthroughSubject<Int, Never>()

        let tracker = PhaseWriteTracker {
            _ = h.render { usePublisher(updateStrategy: nil, { subject.eraseToAnyPublisher() }) }
        }
        tracker.register()

        let emitter = Task.detached(priority: .userInitiated) {
            subject.send(1)
            try await Task.sleep(for: .milliseconds(100))
            subject.send(2)
        }
        try await tracker.waitForWrites(2)
        _ = await emitter.result

        #expect(tracker.recorder.count >= 2, "expected both background emissions to be observed")
        #expect(tracker.recorder.allOnMain, "hook state was written off the main thread")
    }

    @Test("usePublisherPerform completion writes land on the main actor")
    func usePublisherPerformWritesOnMain() async throws {
        let h = StateTest()
        let subject = PassthroughSubject<Int, Never>()

        let perform = h.render {
            usePublisherPerform(updateStrategy: nil, { subject.eraseToAnyPublisher() })
        }.perform
        perform()

        let tracker = PhaseWriteTracker {
            _ = h.render {
                usePublisherPerform(updateStrategy: nil, { subject.eraseToAnyPublisher() }).phase
            }
        }
        tracker.register()

        let emitter = Task.detached(priority: .userInitiated) {
            subject.send(1)
            try await Task.sleep(for: .milliseconds(100))
            subject.send(2)
        }
        try await tracker.waitForWrites(2)
        _ = await emitter.result

        #expect(tracker.recorder.count >= 2)
        #expect(tracker.recorder.allOnMain, "hook state was written off the main thread")
    }

    @Test("usePublisherRefresh writes land on the main actor")
    func usePublisherRefreshWritesOnMain() async throws {
        let h = StateTest()
        let subject = PassthroughSubject<Int, Never>()

        let refresh = h.render {
            usePublisherRefresh(updateStrategy: nil, { subject.eraseToAnyPublisher() })
        }.refresh
        refresh()

        let tracker = PhaseWriteTracker {
            _ = h.render {
                usePublisherRefresh(updateStrategy: nil, { subject.eraseToAnyPublisher() }).phase
            }
        }
        tracker.register()

        let emitter = Task.detached(priority: .userInitiated) {
            subject.send(1)
            try await Task.sleep(for: .milliseconds(100))
            subject.send(2)
        }
        try await tracker.waitForWrites(2)
        _ = await emitter.result

        #expect(tracker.recorder.count >= 2)
        #expect(tracker.recorder.allOnMain, "hook state was written off the main thread")
    }
}
