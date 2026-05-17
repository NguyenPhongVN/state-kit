import SwiftUI
import StateKitAtoms
import StateKitUI
import StateKitMacros

struct Session: Hashable {
    var user: String? = nil
}

@StateAtom
private struct SessionAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> Session { Session() }
}

@ValueAtom
private struct FeedAtom {
    @MainActor
    func value(context: SKAtomTransactionContext) -> [String] {
        let session = context.watch(SessionAtom.shared)
        return session.user == nil ? ["Please sign in"] : ["News", "Trends", "For You"]
    }
}

struct ArchitectureShowcaseExampleView: View {
    @SKState(SessionAtom.shared) private var session
    @SKValue(FeedAtom.shared) private var feed

    var body: some View {
        Form {
            Section("Auth module") {
                LabeledContent("User", value: session.user ?? "Anonymous")
                Button(session.user == nil ? "Sign in" : "Sign out") {
                    session.user = session.user == nil ? "demo@statekit.io" : nil
                }
            }
            Section("Feed module") {
                ForEach(feed, id: \.self) { Text($0) }
            }
        }
        .navigationTitle("Architecture")
    }
}

#Preview {
    NavigationStack {
        ArchitectureShowcaseExampleView()
    }
}
