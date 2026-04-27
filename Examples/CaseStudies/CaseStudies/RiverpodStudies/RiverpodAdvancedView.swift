import SwiftUI
import Riverpods
import StateKit

struct RiverpodAdvancedView: View {
    @Watch(themeOnlyProvider) var theme
    @Environment(\.providerContainer) var container
    
    var body: some View {
        Form {
            Section("Family: Parameterized Providers") {
                VStack(alignment: .leading, spacing: 10) {
                    FamilyUserRow(userID: 1)
                    FamilyUserRow(userID: 42)
                    FamilyUserRow(userID: 99)
                }
                .padding(.vertical, 4)
            }
            
            Section("Select: Performance Optimization") {
                Text("Theme: \(theme)")
                    .font(.headline)
                
                Button("Toggle Theme") {
                    var settings = container.read(settingsProvider)
                    settings.theme = settings.theme == "Dark" ? "Light" : "Dark"
                    container.read(settingsProvider.notifier).state = settings
                }
                
                Button("Change Notifications (No re-render)") {
                    var settings = container.read(settingsProvider)
                    settings.notificationsEnabled.toggle()
                    container.read(settingsProvider.notifier).state = settings
                }
                .foregroundStyle(.secondary)
            }
            
            Section("Testing: Provider Overrides") {
                Text("This section is isolated to its own ProviderScope with an overridden counter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ProviderScope(overrides: [
                    counterProvider.overrideWith(999)
                ]) {
                    OverriddenCounterView()
                }
            }
        }
        .navigationTitle("Riverpod: Advanced")
    }
}

private struct FamilyUserRow: View {
    let userID: Int
    
    var body: some View {
        StateScope {
            let details = useRiverpod(userDetailProvider(userID))
            Label(details, systemImage: "person.circle")
        }
    }
}

private struct OverriddenCounterView: View {
    @Watch(counterProvider) var count
    
    var body: some View {
        HStack {
            Text("Mock Count: \(count)")
                .font(.headline)
                .foregroundStyle(.blue)
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
        }
    }
}
