import SwiftUI
import Combine
import Riverpods
import StateKitMacros

// MARK: - Module 2: Network Service (11 Riverpod Macros)

@MainActor
final class NetworkModule {
    
    @RiverpodNotifier
    class AuthNotifier: Notifier<String?> {
        override func build() -> String? {
            nil
        }
    }
    
    @StateProvider
    struct APIConfig {
        let initial: String = "https://api.social.com"
    }
    
    @Provider
    static func currentHeader(ref: ProviderRef) -> [String: String] {
        [:]
    }
    
    @FutureProvider
    static func fetchInitialData() async -> Bool {
        true
    }
    
    @StreamProvider
    static func socketEvents() -> AnyPublisher<String, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    @ProviderFamily
    static func resourceProvider(ref: ProviderRef, path: String) -> String {
        path
    }
    
    @RiverpodFamily
    class PostNotifier: Notifier<[String]> {
        func build(postId: String) -> [String] {
            []
        }
    }
    
    @RiverpodSelector
    static func isAuthenticated(ref: ProviderRef) -> Bool {
        true
    }
    
    @RiverpodAsync
    static func logout() async {
    }
    
    @RiverpodFutureFamily
    static func commentProvider(id: String) async -> [String] {
        []
    }
    
    @RiverpodStreamFamily
    static func likesProvider(id: String) -> AnyPublisher<Int, Error> {
        Just(0)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
