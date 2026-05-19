import SwiftUI
import StateKitMacros

private enum DemoTheme: String {
    case ocean = "Ocean"
    case sunset = "Sunset"
}

@HookContext
private struct DemoThemeContextValue {
    var theme: DemoTheme = .ocean
}

struct UseContext: View {
    @State private var redrawNonce = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ContextReader(title: "Reader A")
            ContextReader(title: "Reader B")

            Text("Both child views read from the same shared HookContext.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("Toggle shared theme") {
                    _hookContext.value.theme = _hookContext.value.theme == .ocean ? .sunset : .ocean
                    redrawNonce += 1
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ContextReader: StateView {
    let title: String

    var stateBody: some View {
        let theme = useDemoThemeContextValue().theme

        Text("\(title): \(theme.rawValue)")
    }
}
