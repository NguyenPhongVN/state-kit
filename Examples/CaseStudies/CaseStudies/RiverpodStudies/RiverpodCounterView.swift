import SwiftUI
import Riverpods

struct RiverpodCounterView: View {
    @Watch(counterProvider) var count
    @Watch(doubleCounterProvider) var doubleCount
    @Environment(\.providerContainer) var container
    
    var body: some View {
        Form {
            Section("State Management") {
                LabeledContent("Current Count", value: "\(count)")
                LabeledContent("Derived (Count * 2)", value: "\(doubleCount)")
                    .foregroundStyle(.secondary)
            }
            
            Section("Actions") {
                Button("Decrement") {
                    container.read(counterProvider.notifier).state -= 1
                }
                
                Button("Increment") {
                    container.read(counterProvider.notifier).state += 1
                }
                
                Button("Reset") {
                    container.refresh(counterProvider)
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle("Riverpod: Basics")
    }
}
