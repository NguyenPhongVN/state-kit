import SwiftUI
import StateKitAtoms
import StateKitUI
import StateKitMacros

@StateAtom
private struct CacheKeyAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> Int { 1 }
}

@TaskAtom
private struct CachedResponseAtom {
    @MainActor
    func task(context: SKAtomTransactionContext) async -> String {
        let key = context.watch(CacheKeyAtom.shared)
        try? await Task.sleep(nanoseconds: 400_000_000)
        return "Response for key #\(key) at \(Date().formatted(date: .omitted, time: .standard))"
    }
}

struct CacheExampleView: View {
    @SKState(CacheKeyAtom.shared) private var key
    @SKTask(CachedResponseAtom.shared) private var response
    @SKContext private var context

    var body: some View {
        Form {
            Section("Cache Key") {
                Stepper("Key: \(key)", value: $key, in: 1...9)
                Button("Refresh") { Task { await context.refresh(CachedResponseAtom.shared) } }
            }
            Section("Phase") {
                Text(phase)
            }
        }
        .navigationTitle("Task Cache")
    }

    private var phase: String {
        switch response {
        case .idle: return "Idle"
        case .loading: return "Loading..."
        case .success(let value): return value
        case .failure(let error): return error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        CacheExampleView()
    }
}
