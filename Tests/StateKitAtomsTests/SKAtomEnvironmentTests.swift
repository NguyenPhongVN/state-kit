import Testing
import SwiftUI
import StateKit
@testable import StateKitAtoms

@MainActor
@Suite("SKAtom environment")
struct SKAtomEnvironmentTests {

    @Test("default environment falls back to shared store")
    func defaultEnvironmentUsesSharedStore() {
        let environment = EnvironmentValues()
        #expect(environment.skAtomStore === SKAtomStore.shared)
    }
}
