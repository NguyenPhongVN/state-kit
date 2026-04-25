import SwiftUI

struct UseRef: View {
    var body: some View {
        StateScope {
            @HState var syncedValue = 0
            let counterRef = useRef(0)

            VStack(alignment: .leading, spacing: 12) {
                Text("Ref current value: \(counterRef.value)")
                Text("Last synced to UI: \(syncedValue)")
                    .foregroundStyle(.secondary)

                Text("Bam `Increment ref only` se doi ref.value nhung UI khong render lai ngay.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Increment ref only") {
                        counterRef.value += 1
                    }

                    Button("Sync to UI") {
                        syncedValue = counterRef.value
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Reset") {
                        counterRef.value = 0
                        syncedValue = 0
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
