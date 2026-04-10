//import Observation
//import StateKitCore
//
//@Observable
//@MainActor
//public final class AsyncState<T>: @preconcurrency Disposable {
//    
//    public var phase: AsyncPhase<T> = .idle
//    
//    private var task: Task<Void, Never>?
//    
//    public init() {
//        
//    }
//    
//    public func load(_ work: @escaping () async throws -> T) {
//        task?.cancel()
//        task = Task {
//            phase = .loading
//            do {
//                if Task.isCancelled { return }
//                phase = .success(try await work())
//            } catch {
//                phase = .failure(error)
//            }
//        }
//    }
//    
//    public func dispose() {
//        task?.cancel()
//    }
//}
