import SwiftUI
import Combine
import StateKitAtoms
import StateKitMacros

// MARK: - Module 1: User Identity (17 Atom Macros)

@MainActor
final class UserModule {
    
    // MARK: Basic Atoms
    
    @StateAtom
    struct SessionAtom {
        func defaultValue(context: SKAtomTransactionContext) -> String? {
            nil
        }
    }
    
    @ValueAtom
    struct IsLoggedInAtom {
        func value(context: SKAtomTransactionContext) -> Bool {
            context.watch(SessionAtom.shared) != nil
        }
    }
    
    @TaskAtom
    struct ProfileTaskAtom {
        func task(context: SKAtomTransactionContext) async -> String {
            "User Profile"
        }
    }
    
    @ThrowingTaskAtom
    struct SecureDataAtom {
        func task(context: SKAtomTransactionContext) async throws -> Data {
            Data()
        }
    }
    
    @PublisherAtom
    struct NotificationStreamAtom {
        func publisher(context: SKAtomTransactionContext) -> AnyPublisher<Int, Error> {
            Just(0)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }
    
    @Atom
    struct SettingsAtom {
        func defaultValue(context: SKAtomTransactionContext) -> [String: String] {
            [:]
        }
    }

    // MARK: Families
    
    @AtomFamily
    struct UserPrefAtom {
        let key: String
        func defaultValue(context: SKAtomTransactionContext) -> String {
            ""
        }
    }
    
    @SelectorFamily
    struct TranslationAtom {
        let locale: String
        func value(context: SKAtomTransactionContext) -> String {
            locale
        }
    }
    
    @AsyncTaskFamily
    struct FeedTaskAtom {
        let category: String
        func task(context: SKAtomTransactionContext) async -> [String] {
            []
        }
    }

    // MARK: Advanced Atoms
    
    @AtomReducer
    struct FriendsReducer: Hashable {
        typealias State = [String]
        typealias Action = String
        
        func reduce(_ state: inout [String], action: String) {
            state.append(action)
        }
    }

    @Computed
    struct ProfileSummary {
        func compute(context: SKAtomTransactionContext) -> String {
            "Summary"
        }
    }
    
    @SelectorAtom
    struct AdminStatus {
        func select(context: SKAtomTransactionContext) -> Bool {
            false
        }
    }
    
    @FilteredAtom
    struct OnlineFriends {
        func predicate(_ name: String) -> Bool {
            true
        }
    }
    
    @MappedAtom
    struct FriendNames {
        func transform(_ friend: String) -> String {
            friend.uppercased()
        }
    }
    
    @CombineAtom
    struct UserStats {
        func combine(context: SKAtomTransactionContext) -> (Int, Int) {
            (0, 0)
        }
    }
    
    @DistinctAtom
    struct UniqueEvents {
        func source(context: SKAtomTransactionContext) -> Int {
            0
        }
    }
    
    @FlatMapAtom
    struct NestedUpdates {
        func flatMap(context: SKAtomTransactionContext) -> Int {
            0
        }
    }
}
