import SwiftUI

struct UseBinding: View {
    var body: some View {
        StateScope {
            let projectName = useBinding("StateKit")

            VStack(alignment: .leading, spacing: 12) {
                TextField("Project name", text: projectName)
                    .textFieldStyle(.roundedBorder)

                Text("Preview: \(projectName.wrappedValue)")
                Text("Characters: \(projectName.wrappedValue.count)")
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Fill example") {
                        projectName.wrappedValue = "StateKit Hooks"
                    }

                    Button("Clear") {
                        projectName.wrappedValue = ""
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
