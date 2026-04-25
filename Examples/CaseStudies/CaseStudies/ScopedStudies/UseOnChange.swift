import SwiftUI

struct UseOnChange: View {
    var body: some View {
        StateScope {
            @HState var query = ""
            @HState var latestValueLog = "Chua co thay doi"
            @HState var transitionLog = "Chua co transition"
            @HState var initialLog = "Dang cho initial callback"

            let _ = useOnChange(query) { newValue in
                latestValueLog = "New value: \(newValue.isEmpty ? "<empty>" : newValue)"
            }

            let _ = useOnChange(query) { oldValue, newValue in
                let oldText = oldValue.isEmpty ? "<empty>" : oldValue
                let newText = newValue.isEmpty ? "<empty>" : newValue
                transitionLog = "\(oldText) -> \(newText)"
            }

            let _ = useOnChange(query, initial: true) { value in
                initialLog = "Initial-aware callback: \(value.isEmpty ? "<empty>" : value)"
            }

            VStack(alignment: .leading, spacing: 12) {
                TextField("Query", text: $query)
                    .textFieldStyle(.roundedBorder)

                Text(latestValueLog)
                Text(transitionLog)
                Text(initialLog)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Set swift") {
                        query = "swift"
                    }

                    Button("Set hooks") {
                        query = "hooks"
                    }

                    Button("Clear") {
                        query = ""
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
