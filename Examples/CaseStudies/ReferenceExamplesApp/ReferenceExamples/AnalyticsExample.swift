import SwiftUI
import StateKitAtoms
import StateKitUI
import StateKitMacros

@StateAtom
private struct AnalyticsAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> [String] { [] }
}

struct AnalyticsExampleView: View {
    @SKState(AnalyticsAtom.shared) private var events
    @SKContext private var atomContext

    var body: some View {
        Form {
            Section("Track Events") {
                Button("Track screen_view") { trackEvent("screen_view") }
                Button("Track add_to_cart") { trackEvent("add_to_cart") }
                Button("Track checkout") { trackEvent("checkout") }
                Button("Clear") { events = [] }
            }
            Section("Recent") {
                if events.isEmpty {
                    Text("No events yet").foregroundStyle(.secondary)
                } else {
                    ForEach(events, id: \.self) {
                        Text($0).font(.footnote.monospaced())
                    }
                }
            }
        }
        .navigationTitle("Analytics")
    }

    private func trackEvent(_ event: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        events.insert("\(timestamp) - \(event)", at: 0)
    }
}

#Preview {
    NavigationStack {
        AnalyticsExampleView()
    }
}
