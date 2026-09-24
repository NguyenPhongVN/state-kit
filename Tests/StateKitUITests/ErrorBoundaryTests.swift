import Testing
import SwiftUI
import StateKitUI
@testable import StateKitUI

@MainActor
@Suite("ErrorBoundary — DX Essentials")
struct ErrorBoundaryTests {

    private struct Boom: Error {}
    private struct SampleContent: View {
        var body: some View { Text("content") }
    }
    private struct FallbackView: View {
        let error: Error
        var body: some View { Text("fallback: \(error)") }
    }

    @Test("throwing content resolves to the fallback with the error")
    func throwingContentResolvesToFallback() {
        let boundary = ErrorBoundary(
            content: { throw Boom() },
            fallback: { error in FallbackView(error: error) }
        )

        var reported: [Error] = []
        let resolved = boundary.resolve { reported.append($0) }

        guard case .fallback(let error) = resolved else {
            Issue.record("expected fallback resolution")
            return
        }
        #expect(error is Boom)
        #expect(reported.count == 1)
    }

    @Test("clean content resolves to the content view")
    func cleanContentResolvesToContent() {
        let boundary = ErrorBoundary(
            content: { SampleContent() },
            fallback: { error in FallbackView(error: error) }
        )

        var reported: [Error] = []
        let resolved = boundary.resolve { reported.append($0) }

        guard case .content = resolved else {
            Issue.record("expected content resolution")
            return
        }
        #expect(reported.isEmpty)
    }
}
