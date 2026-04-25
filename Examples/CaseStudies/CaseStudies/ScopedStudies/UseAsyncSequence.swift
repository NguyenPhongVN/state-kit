import SwiftUI

struct UseAsyncSequence: View {
    var body: some View {
        StateScope {
            @HState var streamID = 1

            let phase = useAsyncSequence(updateStrategy: .preserved(by: streamID)) {
                AsyncStream<Int> { continuation in
                    let task = Task {
                        for offset in 1...3 {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            guard !Task.isCancelled else { return }
                            continuation.yield(streamID * 10 + offset)
                        }
                        continuation.finish()
                    }

                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Stream id: \(streamID)")
                Text(sequenceDescription(phase))

                HStack {
                    Button("Restart stream") {
                        streamID += 1
                    }
                    .buttonStyle(.borderedProminent)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sequenceDescription(_ phase: AsyncSequencePhase<Int>) -> String {
        switch phase {
        case .idle:
            return "Idle"
        case .loading:
            return "Loading stream..."
        case .value(let element):
            return "Latest element: \(element)"
        case .finished:
            return "Stream finished"
        case .failure(let error):
            return error.localizedDescription
        }
    }
}
