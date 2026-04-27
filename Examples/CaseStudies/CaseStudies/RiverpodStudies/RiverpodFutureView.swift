import SwiftUI
import Riverpods

struct RiverpodFutureView: View {
    @Watch(weatherProvider) var weather
    @Watch(clockProvider) var clock
    @Environment(\.providerContainer) var container
    
    var body: some View {
        Form {
            Section("FutureProvider (Weather API)") {
                switch weather {
                case .data(let condition):
                    LabeledContent("Condition", value: condition)
                case .loading:
                    Text("Fetching weather...")
                case .refreshing(let condition):
                    LabeledContent("Refreshing...", value: condition)
                        .opacity(0.6)
                case .error(let error):
                    Text("Error: \(error.localizedDescription)")
                }
                
                Button("Refresh Weather") {
                    container.refresh(weatherProvider)
                }
            }
            
            Section("StreamProvider (Live Clock)") {
                switch clock {
                case .data(let time):
                    LabeledContent("Server Time", value: time)
                        .monospacedDigit()
                case .loading:
                    ProgressView()
                case .refreshing(let time):
                    LabeledContent("Reconnecting...", value: time)
                        .opacity(0.6)
                case .error(let error):
                    Text("Connection Lost: \(error.localizedDescription)")
                }
            }
        }
        .navigationTitle("Riverpod: Async")
    }
}
