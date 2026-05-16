import Foundation
import SwiftUI
import Riverpods
import StateKit
import StateKitAtoms

// MARK: - Architecture Pattern Showcase

/// This example demonstrates production-grade architecture patterns:
/// 1. Feature modules with clear boundaries
/// 2. Provider composition for complex state
/// 3. Notifier pattern for business logic
/// 4. Cross-feature communication
/// 5. Dependency injection
/// 6. Testing-friendly design

// MARK: - Feature 1: Authentication Module

// Models scoped to feature
struct AuthUser: Sendable, Codable {
    let id: String
    let email: String
    let token: String
}

struct AuthState: Sendable, Codable {
    let user: AuthUser?
    let isLoading: Bool
    let error: String?

    var isAuthenticated: Bool { user != nil }

    static let initial = AuthState(user: nil, isLoading: false, error: nil)
}

// Atoms for authentication state
@SKStateAtom
var authStateAtom: AuthState = .initial

// Notifier for auth business logic
let authServiceNotifier = NotifierProvider { ref -> AuthServiceNotifier in
    AuthServiceNotifier(ref: ref)
}

final class AuthServiceNotifier: Notifier, Sendable {
    let ref: NotifierProviderRef

    init(ref: NotifierProviderRef) {
        self.ref = ref
    }

    func login(email: String, password: String) async {
        updateState { $0.isLoading = true }

        do {
            // Simulate API call
            try await Task.sleep(nanoseconds: 500_000_000)

            let user = AuthUser(
                id: UUID().uuidString,
                email: email,
                token: "token_\(UUID().uuidString)"
            )

            updateState {
                $0.user = user
                $0.isLoading = false
                $0.error = nil
            }
        } catch {
            updateState {
                $0.isLoading = false
                $0.error = error.localizedDescription
            }
        }
    }

    func logout() {
        updateState {
            $0.user = nil
            $0.isLoading = false
            $0.error = nil
        }
    }

    private func updateState(_ update: (inout AuthState) -> Void) {
        let notifier = ref.read(authStateAtom.notifier)
        var current = ref.read(authStateAtom)
        update(&current)
        notifier.state = current
    }
}

// MARK: - Feature 2: User Profile Module

struct UserProfile: Sendable, Codable {
    let userId: String
    let displayName: String
    let bio: String
    let followers: Int
    let following: Int
}

@SKStateAtom
var userProfileAtom: UserProfile?

// Derived state: current user profile
let currentUserProfileProvider = Provider { ref -> UserProfile? in
    let authState = ref.watch(authStateAtom)
    guard let userId = authState.user?.id else { return nil }

    // In real app, would fetch profile from API
    return ref.watch(userProfileAtom)
}

// Family provider for fetching other user profiles
let userProfileFamilyProvider = FutureProvider.family { (ref, userId: String) -> UserProfile in
    // Simulate API call
    try await Task.sleep(nanoseconds: 300_000_000)

    return UserProfile(
        userId: userId,
        displayName: "User \(userId.prefix(4))",
        bio: "Sample bio",
        followers: Int.random(in: 0..<1000),
        following: Int.random(in: 0..<500)
    )
}

// MARK: - Feature 3: Feed Module (Cross-Feature Communication)

struct FeedItem: Sendable, Codable, Identifiable {
    let id: String
    let authorId: String
    let authorName: String
    let content: String
    let timestamp: Date
    let likes: Int
}

@SKStateAtom
var feedItemsAtom: [FeedItem] = []

@SKStateAtom
var likedItemsAtom: Set<String> = []

// Composed provider: feed with like count
let feedWithLikesProvider = Provider { ref -> [FeedItem] in
    var items = ref.watch(feedItemsAtom)
    let liked = ref.watch(likedItemsAtom)

    // Only author can see unliked posts (example business logic)
    let authState = ref.watch(authStateAtom)
    let userId = authState.user?.id ?? ""

    return items.map { item in
        var updated = item
        // Apply computed like count
        if liked.contains(item.id) {
            updated.likes += 1
        }
        return updated
    }
}

// Notifier for feed operations
let feedNotifier = NotifierProvider { ref -> FeedNotifier in
    FeedNotifier(ref: ref)
}

final class FeedNotifier: Notifier, Sendable {
    let ref: NotifierProviderRef

    init(ref: NotifierProviderRef) {
        self.ref = ref
    }

    func likeItem(_ itemId: String) {
        var liked = ref.read(likedItemsAtom)
        liked.insert(itemId)
        ref.read(likedItemsAtom.notifier).state = liked
    }

    func unlikeItem(_ itemId: String) {
        var liked = ref.read(likedItemsAtom)
        liked.remove(itemId)
        ref.read(likedItemsAtom.notifier).state = liked
    }

    func postItem(_ content: String) async {
        // Verify user is authenticated (cross-feature dependency)
        let authState = ref.read(authStateAtom)
        guard let user = authState.user else {
            // Would notify user to log in
            return
        }

        // Simulate posting
        try? await Task.sleep(nanoseconds: 500_000_000)

        let item = FeedItem(
            id: UUID().uuidString,
            authorId: user.id,
            authorName: user.email,
            content: content,
            timestamp: Date(),
            likes: 0
        )

        var items = ref.read(feedItemsAtom)
        items.insert(item, at: 0)
        ref.read(feedItemsAtom.notifier).state = items
    }
}

// MARK: - Composition Pattern

/// Example: Composing multiple notifiers
let composedSocialNotifier = NotifierProvider { ref -> ComposedSocialNotifier in
    ComposedSocialNotifier(
        authNotifier: ref.read(authServiceNotifier),
        feedNotifier: ref.read(feedNotifier),
        ref: ref
    )
}

final class ComposedSocialNotifier: Notifier, Sendable {
    let authNotifier: AuthServiceNotifier
    let feedNotifier: FeedNotifier
    let ref: NotifierProviderRef

    init(authNotifier: AuthServiceNotifier, feedNotifier: FeedNotifier, ref: NotifierProviderRef) {
        self.authNotifier = authNotifier
        self.feedNotifier = feedNotifier
        self.ref = ref
    }

    /// Complex operation using multiple notifiers
    func loginAndViewFeed(email: String, password: String) async {
        // Step 1: Authenticate
        await authNotifier.login(email: email, password: password)

        // Step 2: Verify authentication succeeded
        let authState = ref.read(authStateAtom)
        guard authState.user != nil else {
            return  // Auth failed
        }

        // Step 3: Feed is now automatically computed with auth context
        let feed = ref.read(feedWithLikesProvider)
        // Feed now respects authentication state
    }
}

// MARK: - Views

struct ArchitectureShowcaseView: View {
    @Watch(var authState: authStateAtom)
    @Watch(var feedWithLikes: feedWithLikesProvider)

    @State private var email = "user@example.com"
    @State private var password = "password"

    var body: some View {
        NavigationStack {
            VStack {
                if !authState.isAuthenticated {
                    AuthSection(email: $email, password: $password)
                } else {
                    FeedSection()
                }
            }
            .navigationTitle("Social Network")
        }
    }
}

struct AuthSection: View {
    @Binding var email: String
    @Binding var password: String
    @Watch(var isLoading: authStateAtom.isLoading)

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)

                TextField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            Button(action: authenticate) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Sign In")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)

            Spacer()
        }
    }

    private func authenticate() {
        let container = ProviderContainer()
        let notifier = container.read(authServiceNotifier)

        Task {
            await notifier.login(email: email, password: password)
        }
    }
}

struct FeedSection: View {
    @Watch(var feedWithLikes: feedWithLikesProvider)
    @Watch(var likedItems: likedItemsAtom)
    @Watch(var authState: authStateAtom)

    @State private var newPostText = ""

    var body: some View {
        VStack {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Welcome, \(authState.user?.email ?? "User")!")
                        .font(.headline)
                }

                Spacer()

                Button(action: logout) {
                    Text("Logout")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.systemGray6))

            // Post composer
            VStack(spacing: 8) {
                TextField("What's on your mind?", text: $newPostText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...5)

                HStack {
                    Spacer()
                    Button("Post") {
                        postItem()
                    }
                    .buttonStyle(.bordered)
                    .disabled(newPostText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()

            // Feed list
            List {
                ForEach(feedWithLikes) { item in
                    FeedItemView(item: item, isLiked: likedItems.contains(item.id))
                }
            }
        }
    }

    private func postItem() {
        let container = ProviderContainer()
        let notifier = container.read(feedNotifier)

        Task {
            await notifier.postItem(newPostText)
            newPostText = ""
        }
    }

    private func logout() {
        let container = ProviderContainer()
        let notifier = container.read(authServiceNotifier)
        notifier.logout()
    }
}

struct FeedItemView: View {
    let item: FeedItem
    let isLiked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.authorName)
                        .font(.headline)

                    Text(item.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Text(item.content)
                .font(.body)

            HStack(spacing: 16) {
                Button(action: { toggleLike() }) {
                    HStack {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .gray)

                        Text("\(item.likes)")
                            .font(.caption)
                    }
                }

                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private func toggleLike() {
        let container = ProviderContainer()
        let notifier = container.read(feedNotifier)

        if isLiked {
            notifier.unlikeItem(item.id)
        } else {
            notifier.likeItem(item.id)
        }
    }
}

// MARK: - Preview

#Preview {
    ArchitectureShowcaseView()
}
