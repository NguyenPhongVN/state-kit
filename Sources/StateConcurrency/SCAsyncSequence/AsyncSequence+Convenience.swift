import os

/// Local issue reporter for unimplemented streams — replaces the
/// swift-issue-reporting dependency (whose pinned LockIsolated fails
/// strict-concurrency checks on Xcode 26 runners; spec 014).
@inline(__always)
private func reportUnimplementedIssue(_ message: String) {
    #if DEBUG
    assertionFailure(message)
    #endif
    Logger(subsystem: "app.statekit", category: "unimplemented").error("\(message)")
}
// MARK: - AnyAsyncSequence

extension AsyncStream {
    /// Any asynchronous sequence that causes a test to fail if it runs.
    public static func unimplemented(_ prefix: String) -> Self {
        AsyncStream {
            reportUnimplementedIssue("\(prefix.isEmpty ? "" : "\(prefix) - ")A failing asynchronous sequence ran.")
            $0.finish()
        }
    }
}

// MARK: - AsyncThrowingStream

extension AsyncThrowingStream where Failure == Error {
    /// Any asynchronous sequence that causes a test to fail if it runs.
    public static func unimplemented(_ prefix: String) -> Self {
        AsyncThrowingStream {
            reportUnimplementedIssue("\(prefix.isEmpty ? "" : "\(prefix) - ")A failing asynchronous sequence ran.")
            $0.finish()
        }
    }
}

// MARK: - AsyncPassthroughStream

extension AsyncPassthroughStream {
    /// Any asynchronous sequence that causes a test to fail if it runs.
    public static func unimplemented(_ prefix: String) -> Self {
        let stream = Self()
        reportUnimplementedIssue("\(prefix.isEmpty ? "" : "\(prefix) - ")A failing asynchronous sequence ran.")
        stream.finish()
        return stream
    }

    /// An `AsyncPassthroughStream` that never emits and completes immediately.
    ///
    /// Useful for situations where you must return an asynchronous sequence, but
    /// you don't need to do anything.
    public static var finished: Self {
        let stream = Self()
        stream.finish()
        return stream
    }
}

// MARK: - AsyncCurrentValueStream

extension AsyncCurrentValueStream {
    /// Any asynchronous sequence that causes a test to fail if it runs.
    public static func unimplemented(_ prefix: String, placeholder: Element) -> Self {
        let stream = Self(placeholder)
        reportUnimplementedIssue("\(prefix.isEmpty ? "" : "\(prefix) - ")A failing asynchronous sequence ran.")
        stream.finish()
        return stream
    }
}

// MARK: - AsyncValueStream

extension AsyncValueStream {
    /// Any asynchronous sequence that causes a test to fail if it runs.
    public static func unimplemented(_ prefix: String, placeholder: Element) -> Self {
        let stream = constant(placeholder)
        reportUnimplementedIssue("\(prefix.isEmpty ? "" : "\(prefix) - ")A failing asynchronous sequence ran.")
        return stream
    }
}
