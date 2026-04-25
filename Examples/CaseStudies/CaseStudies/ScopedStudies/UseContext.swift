import SwiftUI

private enum DemoTheme: String {
    case ocean = "Ocean"
    case sunset = "Sunset"
}

private let demoThemeContext = HookContext(DemoTheme.ocean)

struct UseContext: View {
    @State private var redrawNonce = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ContextReader(title: "Reader A", context: demoThemeContext)
            ContextReader(title: "Reader B", context: demoThemeContext)

            Text("Hai view con doc cung mot `HookContext`.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("Toggle shared theme") {
                    demoThemeContext.value = demoThemeContext.value == .ocean ? .sunset : .ocean
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
    let context: HookContext<DemoTheme>

    var stateBody: some View {
        let theme = useContext(context)

        Text("\(title): \(theme.rawValue)")
    }
}
