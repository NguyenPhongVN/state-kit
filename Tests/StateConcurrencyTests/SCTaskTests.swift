import Testing
import Foundation
@testable import StateConcurrency

@Suite("StateConcurrency — SCTask Extensions")
struct SCTaskTests {
    
    final class AtomicCounter: @unchecked Sendable {
        private var _count = 0
        private let lock = NSLock()
        func increment() -> Int {
            lock.lock()
            defer { lock.unlock() }
            _count += 1
            return _count
        }
        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return _count
        }
    }
    
    @Test("Task.retrying succeeds after failures")
    func testTaskRetrySucceeds() async throws {
        let counter = AtomicCounter()
        let result = try await Task.retrying(maxRetryCount: 3, policy: .constant(delay: .milliseconds(1))) { @Sendable in
            let attempts = counter.increment()
            if attempts < 3 {
                throw NSError(domain: "test", code: 1)
            }
            return "Success"
        }.value
        
        #expect(result == "Success")
        #expect(counter.count == 3)
    }
    
    @Test("Task.retrying fails after max retries")
    func testTaskRetryFails() async throws {
        let counter = AtomicCounter()
        do {
            _ = try await Task.retrying(maxRetryCount: 2, policy: .constant(delay: .milliseconds(1))) { @Sendable in
                _ = counter.increment()
                throw NSError(domain: "test", code: 1)
            }.value
            Issue.record("Should have thrown")
        } catch {
            #expect(counter.count == 3) // Initial + 2 retries
        }
    }
    
    @Test("Task.timeout throws on timeout")
    func testTaskTimeout() async throws {
        do {
            _ = try await Task.throwingTimeout(.milliseconds(10)) { @Sendable in
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                return "Done"
            }
            Issue.record("Should have timed out")
        } catch {
            // Success: threw error
        }
    }
    
    @Test("Task.gather executes tasks in parallel")
    func testTaskGather() async throws {
        let results = await Task.gather([
            { @Sendable in "A" },
            { @Sendable in "B" },
            { @Sendable in "C" }
        ])
        
        let values = try results.map { try $0.get() }
        #expect(values.sorted() == ["A", "B", "C"])
    }
    
    @Test("Task.race returns first finisher")
    func testTaskRace() async throws {
        let result = try await Task.race([
            { @Sendable in
                try await Task.sleep(nanoseconds: 50_000_000)
                return "Slow"
            },
            { @Sendable in
                try await Task.sleep(nanoseconds: 10_000_000)
                return "Fast"
            }
        ])
        
        #expect(result == "Fast")
    }
}
