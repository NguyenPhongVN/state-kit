import Foundation
import Observation

/// A class that wraps an asynchronous operation and provides observable state.
///
/// `ObservableTask` is designed for use in SwiftUI views, allowing you to easily
/// track the progress and result of an async operation. It uses the modern
/// `Observation` framework.
///
/// ## Usage Example:
/// ```swift
/// struct MyView: View {
///     @State private var task = ObservableTask {
///         try await fetchData()
///     }
///     
///     var body: some View {
///         VStack {
///             switch task.state {
///             case .idle:
///                 Button("Load") { task.run() }
///             case .running:
///                 ProgressView()
///             case .success(let data):
///                 Text("Loaded: \(data)")
///                 Button("Reload") { task.run() }
///             case .failure(let error):
///                 Text("Error: \(error.localizedDescription)")
///                 Button("Retry") { task.run() }
///             }
///         }
///     }
/// }
/// ```
@Observable
@MainActor
public final class ObservableTask<Success: Sendable, Failure: Error> {
    /// Represents the current state of the task.
    public enum State {
        case idle
        case running
        case success(Success)
        case failure(Failure)
        
        /// The success value, if the task completed successfully.
        public var value: Success? {
            if case .success(let value) = self { return value }
            return nil
        }
        
        /// The error, if the task failed.
        public var error: Failure? {
            if case .failure(let error) = self { return error }
            return nil
        }
        
        /// Whether the task is currently running.
        public var isRunning: Bool {
            if case .running = self { return true }
            return false
        }
    }
    
    /// The current state of the task.
    public private(set) var state: State = .idle
    
    private var currentTask: Task<Void, Never>?
    private let operation: @Sendable () async throws(Failure) -> Success
    
    /// Initializes a new observable task.
    /// - Parameter operation: The async operation to perform.
    public init(operation: @Sendable @escaping () async throws(Failure) -> Success) {
        self.operation = operation
    }
    
    /// Runs the task. If a task is already running, it is cancelled first.
    public func run() {
        cancel()
        state = .running
        
        currentTask = Task {
            do throws(Failure) {
                let result = try await operation()
                if !Task.isCancelled {
                    self.state = .success(result)
                }
            } catch {
                if !Task.isCancelled {
                    self.state = .failure(error)
                }
            }
        }
    }
    
    /// Cancels the currently running task, if any.
    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
}
