import SwiftUI
import Riverpods

struct RiverpodCounterView: View {
    @Watch(RProvider.CounterStateProvider) var count
    @Watch(RProvider.doubleCounterProvider) var doubleCount
    @Environment(\.providerContainer) var container
    
    var body: some View {
        Group {
            LabeledContent("Current Count", value: "\(count)")
            LabeledContent("Derived (Count * 2)", value: "\(doubleCount)")
                .foregroundStyle(.secondary)
            
            Button("Decrement") {
                container.read(RProvider.CounterStateProvider.notifier).state -= 1
            }
            
            Button("Increment") {
                container.read(RProvider.CounterStateProvider.notifier).state += 1
            }
            
            Button("Reset") {
                container.read(RProvider.CounterStateProvider.notifier).state = 0
            }
            .foregroundStyle(.red)
        }
    }
}
