import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class RiverpodMacrosTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "RiverpodNotifier": RiverpodNotifierMacro.self,
        "Provider": ProviderMacro.self,
        "StateProvider": StateProviderMacro.self,
        "FutureProvider": FutureProviderMacro.self,
        "StreamProvider": StreamProviderMacro.self,
        "ProviderFamily": ProviderFamilyMacro.self,
        "RiverpodFamily": RiverpodFamilyMacro.self,
        "RiverpodSelector": RiverpodSelectorMacro.self,
        "RiverpodAsync": RiverpodAsyncMacro.self,
        "RiverpodFutureFamily": RiverpodFutureFamilyMacro.self,
        "RiverpodStreamFamily": RiverpodStreamFamilyMacro.self
    ]

    func testRiverpodNotifierMacro() {
        assertMacroExpansion(
            """
            @RiverpodNotifier
            class AuthNotifier: Notifier<Bool> {
                func build() -> Bool { false }
            }
            """,
            expandedSource: """
            class AuthNotifier: Notifier<Bool> {
                func build() -> Bool { false }
            }

            @MainActor
            let authNotifierProvider = NotifierProvider {
                AuthNotifier()
            }
            """,
            macros: testMacros
        )
    }

    func testStateProviderMacro() {
        assertMacroExpansion(
            """
            @StateProvider
            struct Counter {
                let initial: Int = 0
            }
            """,
            expandedSource: """
            struct Counter {
                let initial: Int = 0
            }

            @MainActor
            let counterProvider = StateProvider { _ in
                0
            }
            """,
            macros: testMacros
        )
    }

    func testProviderMacro() {
        assertMacroExpansion(
            """
            @Provider
            func settings(ref: ProviderRef) -> Int {
                return 0
            }
            """,
            expandedSource: """
            func settings(ref: ProviderRef) -> Int {
                return 0
            }

            @MainActor
            let settingsProvider = Provider { (ref: ProviderRef) -> Int  in
                settings(ref: ref)
            }
            """,
            macros: testMacros
        )
    }

    func testFutureProviderMacro() {
        assertMacroExpansion(
            """
            @FutureProvider
            func fetchUser() async -> String { "" }
            """,
            expandedSource: """
            func fetchUser() async -> String { "" }

            @MainActor
            let fetchUserProvider = FutureProvider { _ in
                await fetchUser()
            }
            """,
            macros: testMacros
        )
    }

    func testStreamProviderMacro() {
        assertMacroExpansion(
            """
            @StreamProvider
            func userUpdates() -> AnyPublisher<Int, Never> { Empty().eraseToAnyPublisher() }
            """,
            expandedSource: """
            func userUpdates() -> AnyPublisher<Int, Never> { Empty().eraseToAnyPublisher() }

            @MainActor
            let userUpdatesProvider = StreamProvider { _ in
                userUpdates()
            }
            """,
            macros: testMacros
        )
    }

    func testProviderFamilyMacro() {
        assertMacroExpansion(
            """
            @ProviderFamily
            func userProfile(ref: ProviderRef, userId: String) -> Profile {
                return Profile()
            }
            """,
            expandedSource: """
            func userProfile(ref: ProviderRef, userId: String) -> Profile {
                return Profile()
            }

            @MainActor
            let userProfileProvider = Provider.family { (ref: ProviderRef, userId: String) -> Profile  in
                userProfile(ref: ref, userId: userId)
            }
            """,
            macros: testMacros
        )
    }

    func testRiverpodFamilyMacro() {
        assertMacroExpansion(
            """
            @RiverpodFamily
            class UserNotifier: Notifier<String> {
                func build(id: String) -> String { id }
            }
            """,
            expandedSource: """
            class UserNotifier: Notifier<String> {
                func build(id: String) -> String { id }
            }

            @MainActor
            let userNotifierFamily = NotifierProvider.family { (arg: String) in
                UserNotifier()
            }
            """,
            macros: testMacros
        )
    }

    func testRiverpodSelectorMacro() {
        assertMacroExpansion(
            """
            @RiverpodSelector
            func authStatus(ref: ProviderRef) -> Bool { true }
            """,
            expandedSource: """
            func authStatus(ref: ProviderRef) -> Bool { true }

            @MainActor
            let authStatusProvider = Provider(authStatus)
            """,
            macros: testMacros
        )
    }

    func testRiverpodAsyncMacro() {
        assertMacroExpansion(
            """
            @RiverpodAsync
            func fetchProfile() async -> String { "" }
            """,
            expandedSource: """
            func fetchProfile() async -> String { "" }

            @MainActor
            let fetchProfileProvider = FutureProvider { ref in
                await fetchProfile()
            }
            """,
            macros: testMacros
        )
    }

    func testRiverpodFutureFamilyMacro() {
        assertMacroExpansion(
            """
            @RiverpodFutureFamily
            func fetchUserDetails(id: String) async -> String { id }
            """,
            expandedSource: """
            func fetchUserDetails(id: String) async -> String { id }

            @MainActor
            let fetchUserDetailsFamily = FutureProvider.family { (ref: ProviderRef, arg: String) in
                await fetchUserDetails(id: arg)
            }
            """,
            macros: testMacros
        )
    }

    func testRiverpodStreamFamilyMacro() {
        assertMacroExpansion(
            """
            @RiverpodStreamFamily
            func observeUser(id: String) -> AnyPublisher<Int, Never> { Empty().eraseToAnyPublisher() }
            """,
            expandedSource: """
            func observeUser(id: String) -> AnyPublisher<Int, Never> { Empty().eraseToAnyPublisher() }

            @MainActor
            let observeUserFamily = StreamProvider.family { (ref: ProviderRef, arg: String) in
                observeUser(id: arg)
            }
            """,
            macros: testMacros
        )
    }
}
