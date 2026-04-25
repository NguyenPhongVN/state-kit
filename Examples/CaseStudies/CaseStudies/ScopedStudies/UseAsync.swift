import SwiftUI

private enum DemoAsyncError: LocalizedError {
    case rejected(Int)

    var errorDescription: String? {
        switch self {
        case .rejected(let id):
            return "Request \(id) duoc demo cho case failure."
        }
    }
}

struct UseAsync: View {
    var body: some View {
        StateScope {
            @HState var requestID = 1
            @HState var reloadToken = 0

            let phase = useAsync(
                updateStrategy: .preserved(by: [AnyHashable(requestID), AnyHashable(reloadToken)])
            ) {
                try await Task.sleep(nanoseconds: 700_000_000)

                if requestID.isMultiple(of: 2) {
                    throw DemoAsyncError.rejected(requestID)
                }

                return "Loaded profile #\(requestID)"
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Request id: \(requestID)")
                Text(asyncDescription(phase))
                    .foregroundStyle(phase.isFailure ? .red : .primary)

                HStack {
                    Button("Next request") {
                        requestID += 1
                    }

                    Button("Retry same request") {
                        reloadToken += 1
                    }
                    .buttonStyle(.borderedProminent)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func asyncDescription(_ phase: AsyncPhase<String>) -> String {
        switch phase {
        case .idle:
            return "Idle"
        case .loading:
            return "Loading..."
        case .success(let value):
            return value
        case .failure(let error):
            return error.localizedDescription
        }
    }
}
