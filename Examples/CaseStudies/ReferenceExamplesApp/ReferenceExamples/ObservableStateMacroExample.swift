import SwiftUI
import StateKitAtoms
import StateKitUI
import StateKitMacros

@ObservableState
final class UserState {
    var count: Int = 0
    var name: String = "Guest"
}

struct ObservableStateMacroExampleView: View {
    @State private var state = UserState()

    var body: some View {
        Form {
            Section("Observation Framework") {
                LabeledContent("Count", value: "\(state.count)")
                LabeledContent("User", value: state.name)
            }
            Section("Actions") {
                Stepper("Adjust Count", value: $state.count)
                TextField("Update Name", text: $state.name)
            }
            Section("Info") {
                Text("This view uses @ObservableState macro which integrates with Apple's Observation framework.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Observable Macro")
    }
}

#Preview {
    NavigationStack {
        ObservableStateMacroExampleView()
    }
}
