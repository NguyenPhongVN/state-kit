import Testing
import Foundation
@testable import StateConcurrency

@Suite("StateConcurrency — Async Streams")
struct AsyncStreamTests {
    
    @Test("AsyncCurrentValueStream emits initial and subsequent values")
    func testCurrentValueStream() async {
        let stream = AsyncCurrentValueStream(0)
        #expect(stream.value == 0)
        
        let task = Task {
            var values: [Int] = []
            for await value in stream {
                values.append(value)
                if value == 2 { break }
            }
            return values
        }
        
        // Give the task a moment to start and receive the initial value
        try? await Task.sleep(nanoseconds: 10_000_000)
        
        stream.send(1)
        stream.send(2)
        
        let values = await task.value
        #expect(values == [0, 1, 2])
        #expect(stream.value == 2)
    }
    
    @Test("AsyncPassthroughStream emits values to multiple iterators")
    func testPassthroughStream() async {
        let stream = AsyncPassthroughStream<Int>()
        
        let task1 = Task {
            var values: [Int] = []
            for await value in stream {
                values.append(value)
                if value == 2 { break }
            }
            return values
        }
        
        let task2 = Task {
            var values: [Int] = []
            for await value in stream {
                values.append(value)
                if value == 2 { break }
            }
            return values
        }
        
        // Give tasks a moment to start
        try? await Task.sleep(nanoseconds: 10_000_000)
        
        stream.send(1)
        stream.send(2)
        
        let values1 = await task1.value
        let values2 = await task2.value
        
        #expect(values1 == [1, 2])
        #expect(values2 == [1, 2])
    }
}
