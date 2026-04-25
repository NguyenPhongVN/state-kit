import Combine
import Testing
import StateKitTesting
import StateKitCombine

@MainActor
@Suite("StateKitCombine")
struct StateKitCombineTests {

    @Test("Publisher.asPhase bridges a publisher into hook state")
    func publisherAsPhase() {
        let harness = StateTest()
        let subject = PassthroughSubject<Int, TestError>()

        let initial = harness.render {
            subject.asPhase()
        }

        subject.send(42)

        let afterValue = harness.render {
            subject.asPhase()
        }

        subject.send(completion: .finished)

        let afterCompletion = harness.render {
            subject.asPhase()
        }

        #expect(initial == .idle)
        #expect(afterValue == .value(42))
        #expect(afterCompletion == .finished)
    }

    @Test("materializeAsPhase emits idle, values, and terminal failure")
    func materializeAsPhase() {
        let publisher = [1, 2].publisher
            .setFailureType(to: TestError.self)
            .append(Fail(error: .sample))

        var phases: [PublisherPhase<Int>] = []
        let cancellable = publisher
            .materializeAsPhase()
            .sink { phases.append($0) }

        _ = cancellable

        #expect(phases.count == 4)
        #expect(phases[0] == .idle)
        #expect(phases[1] == .value(1))
        #expect(phases[2] == .value(2))
        #expect(phases[3].isFailure)
    }

    @Test("PublisherPhase.asPublisher emits the wrapped phase once")
    func phaseAsPublisher() {
        var phases: [PublisherPhase<String>] = []
        let cancellable = PublisherPhase<String>.value("ready")
            .asPublisher()
            .sink { phases.append($0) }

        _ = cancellable

        #expect(phases == [.value("ready")])
    }
}

private enum TestError: Error {
    case sample
}
