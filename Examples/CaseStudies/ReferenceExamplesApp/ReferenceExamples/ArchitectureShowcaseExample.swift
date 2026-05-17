import SwiftUI
import Riverpods

struct Session: Hashable { var user: String? = nil }
private let sessionProvider = StateProvider { _ in Session() }
private let feedProvider = Provider { ref in
    ref.watch(sessionProvider).user == nil ? ["Please sign in"] : ["News", "Trends", "For You"]
}

struct ArchitectureShowcaseExampleView: View {
    @Watch(sessionProvider) var session
    @Watch(feedProvider) var feed
    @Environment(\.providerContainer) var container

    var body: some View {
        Form {
            Section("Auth module") {
                LabeledContent("User", value: session.user ?? "Anonymous")
                Button(session.user == nil ? "Sign in" : "Sign out") {
                    container.read(sessionProvider.notifier).state.user = session.user == nil ? "demo@statekit.io" : nil
                }
            }
            Section("Feed module") {
                ForEach(feed, id: \.self) { Text($0) }
            }
        }
        .navigationTitle("Architecture")
    }
}
