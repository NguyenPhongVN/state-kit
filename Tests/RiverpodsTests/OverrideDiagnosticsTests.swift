import Testing
import Foundation
@testable import Riverpods

@MainActor
@Suite("Override Diagnostics — Clean Public API")
struct OverrideDiagnosticsTests {

    @Test("matched override types produce no diagnostic")
    func matchedTypes() {
        let provider = Provider<Int>(cacheTime: 0) { _ in 0 }
        let diagnostic = ProviderOverrideDiagnostics.mismatchDiagnostic(
            providerID: ProviderID(provider),
            role: "value",
            actualType: Int.self,
            expectedType: Int.self
        )
        #expect(diagnostic == nil)
    }

    @Test("mismatched override value type produces a precise diagnostic")
    func mismatchedValue() throws {
        let provider = Provider<Int>(cacheTime: 0) { _ in 0 }
        let diagnostic = ProviderOverrideDiagnostics.mismatchDiagnostic(
            providerID: ProviderID(provider),
            role: "value",
            actualType: String.self,
            expectedType: Int.self
        )
        let message = try #require(diagnostic)
        #expect(message.contains("value"))
        #expect(message.contains("String"))
        #expect(message.contains("Int"))
    }

    @Test("mismatched override element type produces a precise diagnostic")
    func mismatchedElement() throws {
        let provider = Provider<Int>(cacheTime: 0) { _ in 0 }
        let diagnostic = ProviderOverrideDiagnostics.mismatchDiagnostic(
            providerID: ProviderID(provider),
            role: "element",
            actualType: ProviderElement<Provider<String>>.self,
            expectedType: ProviderElement<Provider<Int>>.self
        )
        let message = try #require(diagnostic)
        #expect(message.contains("element"))
        #expect(message.contains("String"))
        #expect(message.contains("Int"))
    }
}
