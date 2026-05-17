import XCTest

@testable import StateKitMacrosPlugin

final class MacroTests: XCTestCase {
    func testMacrosCompile() {
        // Basic accessibility check for all major macro types
        XCTAssertNotNil(StateAtomMacro.self)
        XCTAssertNotNil(ValueAtomMacro.self)
        XCTAssertNotNil(TaskAtomMacro.self)
        XCTAssertNotNil(PublisherAtomMacro.self)
        XCTAssertNotNil(AtomMacro.self)
        XCTAssertNotNil(HookViewMacro.self)
        XCTAssertNotNil(RiverpodNotifierMacro.self)
        XCTAssertNotNil(ObservableStateMacro.self)
    }

    func testReturnTypeExtractorExists() {
        XCTAssertNotNil(ReturnTypeExtractor.self)
    }

    func testMacroErrorExists() {
        XCTAssertNotNil(MacroError.self)
    }
}
