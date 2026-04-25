import Testing
import StateKit
@testable import StateKitAtoms

@MainActor
@Suite("SKAtomEffect")
struct SKAtomEffectTests {

    final class Recorder: @unchecked Sendable {
        var initializedValue: Int?
        var updates: [(Int, Int)] = []
        var releasedCount = 0
    }

    struct RecordingEffect: SKAtomEffect {
        typealias Value = Int

        let recorder: Recorder

        func initialized(value: Int, context: SKAtomViewContext) {
            recorder.initializedValue = value
        }

        func updated(oldValue: Int, newValue: Int, context: SKAtomViewContext) {
            recorder.updates.append((oldValue, newValue))
        }

        func released() {
            recorder.releasedCount += 1
        }
    }

    struct NoopEffect: SKAtomEffect {
        typealias Value = Int
    }

    @Test("default effect implementations are callable")
    func defaultEffectImplementationsAreCallable() {
        let effect = NoopEffect()
        let context = SKAtomViewContext(store: SKAtomStore())

        effect.initialized(value: 1, context: context)
        effect.updated(oldValue: 1, newValue: 2, context: context)
        effect.released()
    }

    @Test("custom effect methods capture lifecycle events")
    func customEffectMethodsCaptureLifecycleEvents() {
        let recorder = Recorder()
        let effect = RecordingEffect(recorder: recorder)
        let context = SKAtomViewContext(store: SKAtomStore())

        effect.initialized(value: 10, context: context)
        effect.updated(oldValue: 10, newValue: 20, context: context)
        effect.released()

        #expect(recorder.initializedValue == 10)
        #expect(recorder.updates.count == 1)
        #expect(recorder.updates[0].0 == 10)
        #expect(recorder.updates[0].1 == 20)
        #expect(recorder.releasedCount == 1)
    }
}
