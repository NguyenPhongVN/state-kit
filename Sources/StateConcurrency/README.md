# StateConcurrency

A suite of low-level concurrency utilities and extensions for Swift Concurrency and `AsyncSequence`. These tools provide robust patterns for task management, error handling, and reactive stream manipulation within **StateKit**.

## Overview

StateConcurrency is organized into two main parts:
1. **Core Streams:** Implementations like `AsyncCurrentValueStream` and `AsyncPassthroughStream` that bridge imperative code with `AsyncSequence`.
2. **SCTask:** A collection of high-level `Task` and `AsyncSequence` extensions for common concurrency patterns (Retry, Timeout, Gather, Race, etc.).

---

## SCTask Extensions

`SCTask` extends `Task` and `AsyncSequence` with professional-grade patterns for robust asynchronous logic.

### Task Utilities

#### 1. Automatic Retry (`Task.retrying`)
Automatically retry an operation when it fails, using flexible policies like exponential backoff.
```swift
let result = try await Task.retrying(maxRetryCount: 3, policy: .exponential()) {
    try await api.fetchData()
}
```

#### 2. Timeout (`Task.throwingTimeout`)
Ensure an operation doesn't run forever by enforcing a strict time limit.
```swift
let data = try await Task.throwingTimeout(.seconds(5)) {
    try await longRunningOperation()
}
```

#### 3. Gather Results (`Task.gather`)
Execute multiple operations concurrently and collect their results. Supports limiting maximum concurrency to avoid overloading system resources.
```swift
// Collect all results (Success or Failure)
let results = await Task.gather([op1, op2, op3], maxConcurrentTasks: 2)

// Collect only values, throw if any fail
let values = try await Task.gatherThrowing(ops)
```

#### 4. Speed Race (`Task.race`)
Execute multiple operations and return the result of the first one to succeed, automatically cancelling the losers.
```swift
let fastestResult = try await Task.race([fetchFromPrimary, fetchFromMirror])
```

### AsyncSequence Utilities

SCTask adds powerful operators to `AsyncSequence`, similar to Combine but native to Swift Concurrency.

#### Timeout
Throws a `SCTimeoutError` if the sequence doesn't produce an element within the specified duration.
```swift
for try await value in stream.timeout(.seconds(2)) {
    print(value)
}
```

#### Debounce
Emits an element only after a specified duration has passed without another emission (useful for search fields).
```swift
for try await searchTerms in inputSequence.debounce(for: .milliseconds(300)) {
    try await performSearch(searchTerms)
}
```

---

## Core Streams

These classes provide "CurrentValue" and "Passthrough" subjects for the `AsyncSequence` world.

### AsyncCurrentValueStream
An `AsyncSequence` that maintains a "current" value. New subscribers immediately receive the latest value followed by any future updates.
```swift
let stream = AsyncCurrentValueStream(0)
stream.send(1)

for await value in stream {
    print(value) // 1, then future values...
}
```

### AsyncPassthroughStream
An `AsyncSequence` that broadcasts values to multiple subscribers. Unlike `AsyncStream`, it supports multiple iterators and only emits values sent *after* the iterator was created.
```swift
let stream = AsyncPassthroughStream<String>()
stream.send("Hello") // No one hears this
```

---

## Performance & Safety

* **Backpressure Support:** Core streams are designed to respect the natural suspension points of `AsyncSequence`.
* **Memory Management:** `AsyncCurrentValueStream` uses `.bufferingNewest(1)` to prevent memory leaks if consumers fall behind.
* **Strict Concurrency:** All utilities are designed for Swift 6, using `@Sendable` and actor-isolation where appropriate.
