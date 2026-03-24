import SwiftUI
import Textual

struct ContentView: View {
    
    var body: some View {
        ScrollView {
            StructuredText(
                markdown: mdString,
                syntaxExtensions: [.emoji([])]
            )
            .padding()
        }
    }
    
    var mdString: String {
        let url = Bundle.main.url(forResource: "AAA", withExtension: "md")!
        do {
            let string = try String(contentsOf: url, encoding: .utf8)
            print(string)
            return string
        } catch {
            return ""
        }
    }
}

#Preview {
    NavigationStack {
        ContentView()
            .navigationTitle(Text("Textual"))
    }
}
