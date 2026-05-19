import SwiftUI
import Riverpods

struct RiverpodFutureView: View {
    @Watch(RProvider.weatherProvider) var weather
    @Watch(RProvider.clockProvider) var clock
    @Environment(\.providerContainer) var container
    
    var body: some View {
        Group {
            Text("FutureProvider (Weather API)").font(.headline)
            switch weather {
            case .data(let condition):
                LabeledContent("Condition", value: condition)
            case .loading:
                Text("Fetching weather...")
            case .refreshing(let condition):
                LabeledContent("Refreshing...", value: condition)
                    .opacity(0.6)
            case .error(let error, _):
                Text("Error: \(error.localizedDescription)")
            }
            
            Button("Refresh Weather") {
                container.refresh(RProvider.weatherProvider)
            }
            
            Text("StreamProvider (Live Clock)").font(.headline)
            switch clock {
            case .data(let time):
                LabeledContent("Server Time", value: time)
                    .monospacedDigit()
            case .loading:
                ProgressView()
            case .refreshing(let time):
                LabeledContent("Reconnecting...", value: time)
                    .opacity(0.6)
            case .error(let error, _):
                Text("Connection Lost: \(error.localizedDescription)")
            }
        }
    }
}
