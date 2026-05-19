import SwiftUI
import Riverpods
import StateKit

struct RiverpodAdvancedView: View {
    @Watch(RProvider.themeOnlyProvider) var theme
    @Environment(\.providerContainer) var container
    
    var body: some View {
        Group {
            Text("Family: Parameterized Providers").font(.headline)
            FamilyUserRow(userID: 1)
            FamilyUserRow(userID: 42)
            FamilyUserRow(userID: 99)
            
            Text("Select: Performance Optimization").font(.headline)
            Text("Theme: \(theme)")
                .font(.headline)
            
            Button("Toggle Theme") {
                var settings = container.read(RProvider.SettingsProvider)
                settings.theme = settings.theme == "Dark" ? "Light" : "Dark"
                container.read(RProvider.SettingsProvider.notifier).state = settings
            }
            
            Button("Change Notifications (No re-render)") {
                var settings = container.read(RProvider.SettingsProvider)
                settings.notificationsEnabled.toggle()
                container.read(RProvider.SettingsProvider.notifier).state = settings
            }
            .foregroundStyle(.secondary)
            
            Text("Testing: Provider Overrides").font(.headline)
            Text("This section is isolated to its own ProviderScope with an overridden counter.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ProviderScope(overrides: [
                RProvider.CounterStateProvider.overrideWith(999)
            ]) {
                OverriddenCounterView()
            }
        }
    }
}

private struct FamilyUserRow: View {
    let userID: Int
    
    var body: some View {
        StateScope {
            let details = useRiverpod(RProvider.userDetailProvider(userID))
            Label(details, systemImage: "person.circle")
        }
    }
}

private struct OverriddenCounterView: View {
    @Watch(RProvider.CounterStateProvider) var count
    
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
