import XCTest

@testable import StateKitMacrosPlugin

final class MacroTests: XCTestCase {
    func testMacrosCompile() {
        // Verify that all macros are properly defined and accessible
        XCTAssertNotNil(StateAtomMacro.self)
        XCTAssertNotNil(ValueAtomMacro.self)
        XCTAssertNotNil(TaskAtomMacro.self)
        XCTAssertNotNil(PublisherAtomMacro.self)
        XCTAssertNotNil(AtomMacro.self)
        XCTAssertNotNil(ComputedMacro.self)
        XCTAssertNotNil(SelectorAtomMacro.self)
        XCTAssertNotNil(FilteredAtomMacro.self)
        XCTAssertNotNil(MappedAtomMacro.self)
        XCTAssertNotNil(CombineAtomMacro.self)
        XCTAssertNotNil(DistinctAtomMacro.self)
        XCTAssertNotNil(FlatMapAtomMacro.self)
        XCTAssertNotNil(HookViewMacro.self)
        XCTAssertNotNil(ObservableStateMacro.self)
        XCTAssertNotNil(AsyncHookMacro.self)
        XCTAssertNotNil(DebounceMacro.self)
        XCTAssertNotNil(ThrottleMacro.self)
        XCTAssertNotNil(HookPreviousMacro.self)
        XCTAssertNotNil(HookToggleMacro.self)
        XCTAssertNotNil(HookIntervalMacro.self)
        XCTAssertNotNil(RiverpodNotifierMacro.self)
        XCTAssertNotNil(RiverpodFamilyMacro.self)
        XCTAssertNotNil(RiverpodSelectorMacro.self)
        XCTAssertNotNil(RiverpodFutureFamilyMacro.self)
        XCTAssertNotNil(RiverpodStreamFamilyMacro.self)
        XCTAssertNotNil(RiverpodAsyncMacro.self)
    }

    func testReturnTypeExtractorExists() {
        // Verify the utility is accessible
        XCTAssertNotNil(ReturnTypeExtractor.self)
    }

    func testMacroErrorExists() {
        // Verify error enum is accessible
        XCTAssertNotNil(MacroError.self)
    }
}
