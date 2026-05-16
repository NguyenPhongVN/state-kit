import StateKit
import Riverpods

// MARK: - @RiverpodFamily Example

/// Generates: `public let userFamilyProvider = NotifierProvider.family(...)`
@RiverpodFamily
class UserNotifier extends Notifier<User?> {
    final userId = ref.watch(userIdProvider)

    @override
    build(String userId) async {
        return await fetchUser(userId)
    }
}

// Usage:
// @Watch(userFamilyProvider("123")) var user
// Parameterized Riverpod provider with family support

---

// MARK: - @RiverpodSelector Example

/// Generates: `public final isAdminProvider = Provider(isAdmin)`
@RiverpodSelector
final bool isAdmin(ref) {
    final user = await ref.watch(userProvider)
    return user?.role == 'admin' ?? false
}

// Usage:
// @Watch(isAdminProvider) var isAdmin
// Derived provider that selects/computes from other providers

---

// MARK: - Comparison

/*
@riverpodNotifier:
- For simple providers from Notifier classes
- Basic instance generation
- Example: `notifierProvider`

@RiverpodFamily:
- For parameterized Notifier-based providers
- Family factories for multiple instances
- Example: `userFamilyProvider("123")`

@RiverpodSelector:
- For pure selector/derived providers
- Watches other providers and derives values
- Example: `isAdminProvider`
*/
