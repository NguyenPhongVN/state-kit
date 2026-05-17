import SwiftUI

struct RiverpodMacrosGuideView: View {
    private let snippets: [(String, String)] = [
        (
            "@riverpodNotifier",
            """
            @riverpodNotifier
            final class CounterNotifier: Notifier<Int> {
                override func build() -> Int { 0 }
                func increment() { update { $0 + 1 } }
            }
            """
        ),
        (
            "@StateProvider",
            """
            @StateProvider
            struct CounterState {
                let initial = 0
            }
            """
        ),
        (
            "@Provider",
            """
            @Provider
            func welcomeText(ref: ProviderRef) -> String {
                let value = ref.watch(counterNotifierProvider)
                return "Count: \\(value)"
            }
            """
        ),
        (
            "@FutureProvider",
            """
            @FutureProvider
            func delayedMessage() async throws -> String {
                try await Task.sleep(for: .milliseconds(150))
                return "Loaded"
            }
            """
        ),
        (
            "@RiverpodSelector",
            """
            @RiverpodSelector
            func isEven(ref: ProviderRef) -> Bool {
                ref.watch(counterNotifierProvider).isMultiple(of: 2)
            }
            """
        )
    ]

    var body: some View {
        List {
            Section("Riverpod Macros") {
                Text("Examples below are macro-only API usage (no manual provider wiring).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(snippets, id: \.0) { title, code in
                Section(title) {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(code)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle("Riverpod Macros")
    }
}

#Preview {
    NavigationStack {
        RiverpodMacrosGuideView()
    }
}
