import Foundation

/// An actor that limits the number of concurrently executing tasks.
///
/// `SCConcurrencyLimiter` provides a way to throttle the execution of asynchronous
/// operations, ensuring that no more than `maxConcurrentTasks` are running at the same time.
/// Additional tasks are queued and executed as slots become available.
public actor SCConcurrencyLimiter {
    private let maxConcurrentTasks: Int
    private var activeTasks = 0
    private var waitingTasks: [UUID: CheckedContinuation<Bool, Never>] = [:]
    private var waitingOrder: [UUID] = []
    
    /// Initializes a new concurrency limiter.
    /// - Parameter maxConcurrentTasks: The maximum number of tasks to allow concurrently.
    public init(maxConcurrentTasks: Int) {
        self.maxConcurrentTasks = maxConcurrentTasks
    }
    
    /// Executes an operation, waiting for a slot if the limit has been reached.
    /// - Parameter operation: The operation to execute.
    /// - Returns: The result of the operation.
    public func execute<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        let id = UUID()
        var acquired = false
        
        // Wait for a slot, handling cancellation
        await withTaskCancellationHandler {
            acquired = await wait(id: id)
        } onCancel: {
            Task { [id] in
                await self.cancelWait(id: id)
            }
        }
        
        guard acquired else {
            throw CancellationError()
        }
        
        defer { signal() }
        try Task.checkCancellation()
        
        return try await operation()
    }
    
    private func wait(id: UUID) async -> Bool {
        if activeTasks < maxConcurrentTasks {
            activeTasks += 1
            return true
        }
        
        return await withCheckedContinuation { continuation in
            waitingTasks[id] = continuation
            waitingOrder.append(id)
        }
    }
    
    private func cancelWait(id: UUID) {
        if let continuation = waitingTasks.removeValue(forKey: id) {
            waitingOrder.removeAll(where: { $0 == id })
            continuation.resume(returning: false)
        }
    }
    
    private func signal() {
        while !waitingOrder.isEmpty {
            let id = waitingOrder.removeFirst()
            if let continuation = waitingTasks.removeValue(forKey: id) {
                continuation.resume(returning: true)
                return
            }
        }
        activeTasks -= 1
    }
}
