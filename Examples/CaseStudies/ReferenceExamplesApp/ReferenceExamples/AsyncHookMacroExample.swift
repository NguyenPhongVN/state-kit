import SwiftUI
import StateKitAtoms
import StateKitUI

private struct AsyncSeedAtom: SKStateAtom, Hashable {
    typealias Value = Int
    func defaultValue(context: SKAtomTransactionContext) -> Int { 1 }
}

private struct AsyncFailAtom: SKStateAtom, Hashable {
    typealias Value = Bool
    func defaultValue(context: SKAtomTransactionContext) -> Bool { false }
}

private enum AsyncDemoError: LocalizedError {
    case forced
    var errorDescription: String? { "Forced error for demo." }
}

private struct AsyncProfileAtom: SKThrowingTaskAtom, Hashable {
    typealias TaskSuccess = String
    func task(context: SKAtomTransactionContext) async throws -> String {
        let id = context.watch(AsyncSeedAtom())
        let shouldFail = context.watch(AsyncFailAtom())
        try await Task.sleep(nanoseconds: 500_000_000)
        if shouldFail { throw AsyncDemoError.forced }
        return "Loaded profile #\(id)"
    }
}

struct AsyncHookMacroExampleView: View {
    @SKState(AsyncSeedAtom()) private var requestID
    @SKState(AsyncFailAtom()) private var shouldFail
    @SKTask(AsyncProfileAtom()) private var profile
    @SKContext private var atomContext

    var body: some View {
        Form {
            Section("Async Atom API") {
                Stepper("Request: \(requestID)", value: $requestID, in: 1...9)
                Toggle("Force failure", isOn: $shouldFail)
                Button("Refresh") {
                    Task { await atomContext.refresh(AsyncProfileAtom()) }
                }
            }
            Section("Phase") {
                Text(phaseText)
            }
        }
        .navigationTitle("Async Task Atom")
    }

    private var phaseText: String {
        switch profile {
        case .idle: return "Idle"
        case .loading: return "Loading..."
        case .success(let value): return value
        case .failure(let error): return error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        AsyncHookMacroExampleView()
    }
}
