import SwiftUI

struct UseEffect: View {
    var body: some View {
        StateScope {
            @HState var isEnabled = false
            @HState var logs: [String] = []

            let _ = useEffect(updateStrategy: .preserved(by: isEnabled)) {
                logs.append("effect run, enabled = \(isEnabled)")

                guard isEnabled else { return nil }

                return {
                    logs.append("cleanup before enabled changes")
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Enabled: \(isEnabled ? "true" : "false")")

                HStack {
                    Button(isEnabled ? "Disable" : "Enable") {
                        isEnabled.toggle()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Clear log") {
                        logs.removeAll()
                    }
                }
                .buttonStyle(.bordered)

                DemoLogList(items: logs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
