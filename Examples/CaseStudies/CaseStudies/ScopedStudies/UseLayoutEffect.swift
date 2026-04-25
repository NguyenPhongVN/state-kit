import SwiftUI

struct UseLayoutEffect: View {
    var body: some View {
        StateScope {
            @HState var step = 0
            @HState var events: [String] = []

            let _ = useLayoutEffect(updateStrategy: .preserved(by: step)){
                events.append("layout effect for step \(step)")
                return nil
            }

            let _ = useEffect(updateStrategy: .preserved(by: step)) {
                events.append("passive effect for step \(step)")
                return nil
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Current step: \(step)")

                Text("Moi lan `step` doi, log se cho thay layout effect duoc flush truoc effect thuong.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Next step") {
                        step += 1
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Clear log") {
                        events.removeAll()
                    }
                }
                .buttonStyle(.bordered)

                DemoLogList(items: events)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
