import SwiftUI
import StateKitMacros

@HookState
private struct ProjectForm {
    var projectName: String = "StateKit"
}

/// Demonstrates binding-based local state using a struct + `@HookState` macro.
///
/// `@HookState` generates `useProjectForm(...) -> Binding<ProjectForm>`.
/// This keeps local form state typed as a struct while still giving direct
/// `Binding` access for SwiftUI controls.
///
/// Behavior in this example:
/// - Editing the text field updates `projectName` in local hook state.
/// - Programmatic writes through the binding also update the UI.
/// - Derived UI (`Preview` and `Characters`) re-renders when the value changes.
struct UseBinding: View {
    var body: some View {
        StateScope {
            let form = useProjectForm()

            VStack(alignment: .leading, spacing: 12) {
                TextField("Project name", text: form.projectName)
                    .textFieldStyle(.roundedBorder)

                Text("Preview: \(form.wrappedValue.projectName)")
                Text("Characters: \(form.wrappedValue.projectName.count)")
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Fill example") {
                        form.wrappedValue.projectName = "StateKit Hooks"
                    }

                    Button("Clear") {
                        form.wrappedValue.projectName = ""
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
