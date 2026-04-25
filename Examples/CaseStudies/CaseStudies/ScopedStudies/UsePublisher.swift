import Combine
import SwiftUI

struct UsePublisher: View {
    var body: some View {
        StateScope {
            @HState var publisherID = 1

            let phase = usePublisher(updateStrategy: .preserved(by: publisherID)) {
                Timer.publish(every: 0.5, on: .main, in: .common)
                    .autoconnect()
                    .prefix(3)
                    .map { date in
                        "Publisher \(publisherID): \(date.formatted(date: .omitted, time: .standard))"
                    }
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Publisher id: \(publisherID)")
                Text(publisherDescription(phase))

                HStack {
                    Button("Restart publisher") {
                        publisherID += 1
                    }
                    .buttonStyle(.borderedProminent)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func publisherDescription(_ phase: PublisherPhase<String>) -> String {
        switch phase {
        case .idle:
            return "Idle"
        case .value(let output):
            return output
        case .finished:
            return "Publisher finished"
        case .failure(let error):
            return error.localizedDescription
        }
    }
}
