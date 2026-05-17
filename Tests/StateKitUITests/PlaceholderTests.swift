import Testing
import SwiftUI
@testable import StateKitUI

@Suite("StateKitUI — TypeName")
@MainActor
struct TypeNameTests {
    @Test("abbreviates Optional, Array, and Dictionary")
    func abbreviatesSwiftContainerTypes() {
        #expect(typeName(Optional<Int>.self, qualified: true, genericsAbbreviated: false) == "Int?")
        #expect(typeName(Array<String>.self, qualified: true, genericsAbbreviated: false) == "[String]")
        #expect(typeName(Dictionary<String, Int>.self, qualified: true, genericsAbbreviated: false) == "[String: Int]")
    }

    @Test("drops generic arguments when requested")
    func dropsGenericArguments() {
        struct Box<T> {}
        #expect(typeName(Box<Int>.self, qualified: false, genericsAbbreviated: true) == "Box")
    }

    @Test("keeps type qualification when enabled")
    func keepsQualificationWhenEnabled() {
        let qualified = typeName(StateScope<Text>.self, qualified: true, genericsAbbreviated: true)
        #expect(qualified.contains("StateScope"))
    }
}
