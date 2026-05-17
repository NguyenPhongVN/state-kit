import SwiftUI
import StateKitAtoms
import StateKitUI

private let objectScaleAtom = atomFamily { (id: Int) in Double(id) }
private let objectLabelAtom = selectorFamily { (id: Int, context: SKAtomTransactionContext) in
    "Object \(id) scale \(context.watch(objectScaleAtom(id)).formatted(.number.precision(.fractionLength(1))))"
}

struct VisionOSExampleView: View {
    var body: some View {
        Form {
            Section("Spatial objects") {
                ForEach(1...3, id: \.self) { id in
                    SKAtomScopeView {
                        let scale = useAtomBinding(objectScaleAtom(id))
                        let label = useAtomValue(objectLabelAtom(id))
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
