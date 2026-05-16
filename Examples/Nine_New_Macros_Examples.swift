import StateKit

// MARK: - ATOM MACROS (3 New)

// 1. @CombineAtom - Merge multiple atoms
@CombineAtom
struct UserWithSettingsAtom {
    func combine(context: AtomContext) -> (User, UserSettings) {
        let user = context.watch(UserAtom())
        let settings = context.watch(UserSettingsAtom())
        return (user, settings)
    }
}

// Usage: let (user, settings) = context.value(UserWithSettingsAtom())

---

// 2. @DistinctAtom - Only emit distinct values
@DistinctAtom
struct SearchQueryAtom {
    func source(context: AtomContext) -> String {
        context.watch(SearchInputAtom())
    }
}

// Filters out duplicate consecutive strings
// Useful to avoid redundant API calls on the same query

---

// 3. @FlatMapAtom - Flatten nested async values
@FlatMapAtom
struct UserPostsAtom {
    func flatMap(context: AtomContext) async -> [Post] {
        let user = context.watch(UserAtom())
        return await API.fetchUserPosts(user.id)
    }
}

// Usage: let posts = context.value(UserPostsAtom())
// Handles async chains cleanly

---

// MARK: - HOOK MACROS (3 New)

// 4. @HookPrevious - Track previous value
@HookPrevious
struct PreviousCountHook {
    let count: Int
}

// Usage: let previousCount = usePreviousCountHook(count: 5)
// Returns: Optional<Int> - the previous value

// Useful for:
// - Detecting if value increased/decreased
// - Animations (animate from previous to current)
// - Change comparisons

---

// 5. @HookToggle - Boolean toggle helper
@HookToggle
struct IsMenuOpenHook {
    // Generates: useIsMenuOpen() -> (Bool, () -> Void)
}

// Usage:
// let (isOpen, toggle) = useIsMenuOpen()
// Button("Toggle") { toggle() }

// Replaces:
// let (state, setState) = useState(false)
// let toggle = { setState(!state) }

---

// 6. @HookInterval - Polling/timer hook
@HookInterval
struct CountdownHook {
    let intervalMs: Int = 1000  // 1 second

    func tick() async {
        updateTimer()
    }
}

// Usage: useCountdownHook()
// Automatically handles setup/teardown
// Calls tick() every 1 second

// Useful for:
// - Timers/countdowns
// - Polling data every N seconds
// - Real-time updates

---

// MARK: - RIVERPOD MACROS (3 New)

// 7. @RiverpodFutureFamily - Parameterized async provider
@RiverpodFutureFamily
final class fetchUserFuture(id: String) async {
    return await API.getUser(id)
}

// Usage: @Watch(fetchUserFamilyProvider("123")) var user
// Generates: public final fetchUserFamilyProvider = FutureProvider.family(...)

---

// 8. @RiverpodStreamFamily - Parameterized stream provider
@RiverpodStreamFamily
final class watchUserStream(id: String) async* {
    for await user in API.watchUser(id) {
        yield user
    }
}

// Usage: @Watch(watchUserStreamFamilyProvider("123")) var userUpdates
// Real-time updates for parameterized resources

---

// 9. @RiverpodAsync - Cleaner async provider
@RiverpodAsync
final class currentUserProvider async {
    return await API.getCurrentUser()
}

// Usage: @Watch(currentUserAsyncProvider) var user
// Simpler syntax than @FutureProvider

// Comparison:
// @FutureProvider - requires manual wrapping
// @RiverpodAsync - direct async function
