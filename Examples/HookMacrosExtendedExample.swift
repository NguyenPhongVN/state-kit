import StateKit

// MARK: - @Debounce Example

/// Delays search execution until user stops typing for 300ms
@HookEffect
struct SearchEffect {
    let query: String

    @Debounce(milliseconds: 300)
    func run() {
        performSearch(query)
    }
}

// Usage in a view:
// useSearchEffect(query: searchText)
// Automatically debounces the search function

---

// MARK: - @Throttle Example

/// Limits scroll event handling to once per 100ms
@HookEffect
struct ScrollTrackingEffect {
    let scrollY: CGFloat

    @Throttle(milliseconds: 100)
    func run() {
        updateScrollPosition(scrollY)
    }
}

// Usage: useScrollTrackingEffect(scrollY: offset)
// Throttles updates for better performance

---

// MARK: - Debounce vs Throttle

/*
@Debounce:
- Waits until calls STOP before executing
- Best for: Search, auto-save, form validation
- Example: User types "swift" → Wait 300ms → Execute once

@Throttle:
- Executes at most once per interval
- Best for: Scroll, resize, frequent events
- Example: Scroll events → Execute at most every 100ms
*/
