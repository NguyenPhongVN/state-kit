import SwiftUI
import StateKitAtoms
import StateKitUI
import StateKitMacros

@AtomFamily
private struct ObjectScaleAtom {
    let id: Int
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> Double {
        return Double(id)
    }
}

@SelectorFamily
private struct ObjectLabelAtom {
    let id: Int
    @MainActor
    func value(context: SKAtomTransactionContext) -> String {
        let scale = context.watch(ObjectScaleAtom.family(id))
        return "Object \(id) scale \(scale.formatted(.number.precision(.fractionLength(1))))"
    }
}

struct VisionOSExampleView: View {
    var body: some View {
        Form {
            Section("Spatial objects") {
                ForEach([1, 2, 3], id: \.self) { id in
                    SKAtomScopeView {
                        let scale = useAtomBinding(ObjectScaleAtom.family(id))
                        let label = useAtomValue(ObjectLabelAtom.family(id))
                        VStack(alignment: .leading) {
                            Text(label)
                            Slider(value: scale, in: 0.5...3.0)
                        }
                    }
                }
            }
        }
        .navigationTitle("visionOS State")
    }
}

#Preview {
    NavigationStack {
        VisionOSExampleView()
    }
}
