import SwiftUI
import Riverpods

final class AnalyticsNotifier: Notifier<[String]> {
    override func build() -> [String] { [] }

    func track(_ event: String) {
        state.insert("\(Date().formatted(date: .omitted, time: .standard)) - \(event)", at: 0)
    }

    func clear() { state = [] }
}

private let analyticsProvider = NotifierProvider { AnalyticsNotifier() }

struct AnalyticsExampleView: View {
    @Watch(analyticsProvider) var events
    @Watch(analyticsProvider.notifier) var notifier

    var body: some View {
        Form {
            Section("Track Events") {
                Button("Track screen_view") { notifier.track("screen_view") }
                Button("Track add_to_cart") { notifier.track("add_to_cart") }
                Button("Track checkout") { notifier.track("checkout") }
                Button("Clear") { notifier.clear() }
            }
            Section("Recent") {
                if events.isEmpty { Text("No events yet").foregroundStyle(.secondary) }
                ForEach(events, id: \.self) { Text($0).font(.footnote.monospaced()) }
            }
        }
        .navigationTitle("Analytics")
    }
}
