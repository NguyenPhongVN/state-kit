import Foundation
import Combine

// MARK: - Family ID

struct FamilyMemberID: Hashable {
    let familyID: UUID
    let argument: AnyHashable
}

// MARK: - Provider Family

extension Provider {
    /// Tạo một nhóm các Provider dựa trên tham số truyền vào.
    public static func family<Arg: Hashable & Sendable>(
        autoDispose: Bool = true,
        _ factory: @MainActor @escaping (ProviderRef, Arg) -> T
    ) -> (Arg) -> Provider<T> {
        let familyID = UUID()
        return { arg in
            Provider(
                id: FamilyMemberID(familyID: familyID, argument: AnyHashable(arg)),
                autoDispose: autoDispose
            ) { ref in
                factory(ref, arg)
            }
        }
    }
}

// MARK: - StateProvider Family

extension StateProvider {
    public static func family<Arg: Hashable & Sendable>(
        autoDispose: Bool = true,
        _ factory: @MainActor @escaping (ProviderRef, Arg) -> T
    ) -> (Arg) -> StateProvider<T> {
        let familyID = UUID()
        return { arg in
            StateProvider(
                id: FamilyMemberID(familyID: familyID, argument: AnyHashable(arg)),
                autoDispose: autoDispose
            ) { ref in
                factory(ref, arg)
            }
        }
    }
}

// MARK: - NotifierProvider Family

extension NotifierProvider {
    public static func family<Arg: Hashable & Sendable>(
        autoDispose: Bool = true,
        _ factory: @MainActor @escaping (Arg) -> N
    ) -> (Arg) -> NotifierProvider<N, T> {
        let familyID = UUID()
        return { arg in
            NotifierProvider(
                id: FamilyMemberID(familyID: familyID, argument: AnyHashable(arg)),
                autoDispose: autoDispose
            ) {
                factory(arg)
            }
        }
    }
}

// MARK: - FutureProvider Family

extension FutureProvider {
    public static func family<Arg: Hashable & Sendable>(
        autoDispose: Bool = true,
        _ factory: @MainActor @escaping (ProviderRef, Arg) async throws -> T
    ) -> (Arg) -> FutureProvider<T> {
        let familyID = UUID()
        return { arg in
            FutureProvider(
                id: FamilyMemberID(familyID: familyID, argument: AnyHashable(arg)),
                autoDispose: autoDispose
            ) { ref in
                try await factory(ref, arg)
            }
        }
    }
}

// MARK: - StreamProvider Family

extension StreamProvider {
    public static func family<Arg: Hashable & Sendable>(
        autoDispose: Bool = true,
        _ factory: @MainActor @escaping (ProviderRef, Arg) -> AnyPublisher<T, Error>
    ) -> (Arg) -> StreamProvider<T> {
        let familyID = UUID()
        return { arg in
            StreamProvider(
                id: FamilyMemberID(familyID: familyID, argument: AnyHashable(arg)),
                autoDispose: autoDispose
            ) { ref in
                factory(ref, arg)
            }
        }
    }
}
