# StateKit Extended Features Guide

**Version**: 2.6.0-beta  
**Last Updated**: May 2026  
**Total Pages**: 50+

---

## Table of Contents

1. [Overview](#overview)
2. [Part 1: Caching Strategies](#part-1-caching-strategies) (Pages 1-15)
3. [Part 2: Feature Flags & A/B Testing](#part-2-feature-flags--ab-testing) (Pages 16-30)
4. [Part 3: Analytics & User Journey](#part-3-analytics--user-journey) (Pages 31-45)
5. [Advanced Patterns](#advanced-patterns) (Pages 46-50)

---

## Overview

StateKit now includes three powerful production utilities:

- **StateKitCache**: Advanced caching with LRU, LFU, TTL, and custom strategies
- **StateKitFeatureFlags**: Type-safe feature flags with A/B testing and gradual rollouts
- **StateKitAnalytics**: Structured event tracking with funnel and cohort analysis

These modules are designed to solve real production problems: performance optimization, risk mitigation, and user behavior understanding.

---

# Part 1: Caching Strategies

## 1. Introduction to Caching

Caching is fundamental to performance optimization in modern applications. By storing expensive operation results, you can:

- **Reduce latency**: Serve data from memory instead of network/disk
- **Lower costs**: Fewer API calls means reduced backend load
- **Improve UX**: Faster app response times create better user experience

StateKit provides multiple caching strategies for different use cases.

## 2. LRU Cache (Least Recently Used)

**Best for**: General-purpose caching of bounded size, working set cache

```swift
import StateKitCache

// Create LRU cache with 100-item capacity
let cache = LRUCache<String, Product>(capacity: 100)

// Set value
cache.set("prod-123", value: product)

// Get value
if let cached = cache.get("prod-123") {
    // Use cached product
}

// Monitor statistics
let stats = cache.stats
print("Hit rate: \(stats.hitRate * 100)%")
print("Size: \(stats.size)/\(stats.capacity)")
```

### How LRU Works

When capacity is exceeded, the least recently accessed item is evicted:

1. Items are tracked by access order
2. Every `get()` or `set()` updates access time
3. When new item can't fit, least recent is removed
4. Perfect for working sets where recent data is more likely to be needed

### LRU Example: Search Query Cache

```swift
@MainActor
final class SearchService {
    private let cache = LRUCache<String, [SearchResult]>(capacity: 50)
    
    func search(_ query: String) async -> [SearchResult] {
        // Check cache first
        if let cached = cache.get(query) {
            return cached
        }
        
        // Perform expensive search
        let results = try await performSearch(query)
        cache.set(query, value: results)
        return results
    }
}
```

### LRU Configuration

```swift
// Small cache for frequently accessed data
let hotCache = LRUCache<String, User>(capacity: 100)

// Medium cache for working set
let workingCache = LRUCache<String, Document>(capacity: 1000)

// Large cache with eviction callbacks
let fileCache = LRUCache<String, FileData>(capacity: 500)
fileCache.onEvict { key, reason in
    // Handle eviction (e.g., cleanup resources)
    print("Evicted \(key) due to \(reason)")
}
```

## 3. LFU Cache (Least Frequently Used)

**Best for**: Working sets with hot/cold data separation

LFU tracks frequency of access and evicts least frequently used items:

```swift
import StateKitCache

let cache = LFUCache<String, Data>(capacity: 100)

// Frequently accessed items stay longer
for _ in 0..<10 {
    let data = cache.get("hot-key")  // Frequency increases
}

// Rarely accessed items evicted first when full
cache.set("cold-key", value: data)
```

### LFU vs LRU

| Aspect | LRU | LFU |
|--------|-----|-----|
| Evicts | Least recently used | Least frequently used |
| Best for | Sequential access patterns | Hot/cold working sets |
| Memory | Lower overhead | Higher (frequency tracking) |
| Warm-up | Requires repeated access | More stable over time |

### LFU Example: Image Cache

```swift
// Images that are frequently viewed stay in cache
let imageCache = LFUCache<String, UIImage>(capacity: 50)

// Popular images (viewed frequently)
for _ in 0..<100 {
    let image = imageCache.get("popular.jpg")
}

// Rare images evicted first when space needed
imageCache.set("rare-background.png", value: image)
```

## 4. TTL Cache (Time-To-Live)

**Best for**: Time-sensitive data with automatic expiration

TTL caches automatically remove stale items:

```swift
import StateKitCache

// Cache expires after 5 minutes (300 seconds)
let cache = TTLCache<String, APIResponse>(ttl: 300)

// Set value (auto-expires in 5 minutes)
cache.set("api-response", value: response)

// Get value (returns nil if expired)
if let response = cache.get("api-response") {
    // Still fresh
}
```

### TTL Configuration

```swift
// Short TTL for rapidly changing data
let shortCache = TTLCache<String, StockPrice>(ttl: 30)  // 30 seconds

// Medium TTL for user data
let userCache = TTLCache<String, User>(ttl: 3600)  // 1 hour

// Long TTL for static data
let staticCache = TTLCache<String, Product>(ttl: 86400)  // 1 day

// Custom cleanup interval
let cache = TTLCache<String, Data>(ttl: 300, cleanupInterval: 60)
```

### TTL Example: Weather Data Cache

```swift
@MainActor
final class WeatherService {
    private let cache = TTLCache<String, Weather>(ttl: 600)  // 10 minutes
    
    func getWeather(city: String) async -> Weather {
        if let cached = cache.get(city) {
            return cached  // Use fresh cached data
        }
        
        let weather = try await fetchWeather(city)
        cache.set(city, value: weather)
        return weather
    }
}
```

### On-Expire Callbacks

```swift
let cache = TTLCache<String, Session>(ttl: 1800)

cache.onExpire { key, session in
    // Cleanup when session expires
    analytics.trackSessionEnd(session)
    database.deleteSessions([key])
}
```

## 5. Sliding Window TTL Cache

**Best for**: Session data where activity extends timeout

Sliding window resets TTL on access:

```swift
let cache = SlidingWindowTTLCache<String, Session>(ttl: 1800)

// Initial set - expires in 30 minutes
cache.set("session-1", value: session)

// Getting extends TTL by another 30 minutes
let session = cache.get("session-1")

// Gets within 30 min of last access: not expired
// Gets after 30 min of inactivity: expired
```

### Sliding Window Use Cases

```swift
// Session cache: extend timeout while user is active
let sessionCache = SlidingWindowTTLCache<String, UserSession>(ttl: 1800)

// Active user extends session every time we check
if let session = sessionCache.get(userId) {
    // Still active - TTL extended
    continueSession(session)
} else {
    // Inactive for 30 min - expired
    requireNewLogin()
}
```

## 6. Cache-Aside Pattern

**Best for**: Transparent caching of expensive operations

Cache-aside automatically manages getting/setting:

```swift
import StateKitCache

let cache = LRUCache<String, Product>(capacity: 100)
let cacheAside = CacheAsidePattern(cache: cache) { key in
    try await fetchProduct(key)  // Called on cache miss
}

// Get automatically handles cache + fetch
let product = try await cacheAside.get("prod-123")
```

### Cache-Aside Example: Database Queries

```swift
let cache = TTLCache<String, [User]>(ttl: 300)
let queryCache = CacheAsidePattern(cache: cache) { query in
    try await database.query(query)
}

// Transparent caching
let activeUsers = try await queryCache.get("SELECT * FROM users WHERE active=true")
// First call: fetches from DB
// Subsequent calls within TTL: returns cached result
```

### Manual Cache-Aside

```swift
func getUser(id: String) async throws -> User {
    // Check cache
    if let cached = cache.get(id) {
        return cached
    }
    
    // Not in cache - fetch
    let user = try await fetchUser(id)
    
    // Store in cache
    cache.set(id, value: user)
    
    return user
}
```

## 7. Write-Through Pattern

**Best for**: Ensuring consistency between cache and persistence

Write-through writes to both cache and storage:

```swift
import StateKitCache

let cache = LRUCache<String, Product>(capacity: 100)
let writeThrough = WriteThroughPattern(
    cache: cache,
    writer: { key, value in
        // Write to persistent storage
        try await database.save(key: key, value: value)
    }
)

// Write updates both cache and database
try await writeThrough.set("prod-123", value: product)
```

## 8. Cache Preloading

**Best for**: Warming cache with known frequently-used data

Preloading fills cache before users access data:

```swift
let cache = LRUCache<String, Product>(capacity: 100)
let preloader = CachePreloader(cache: cache)

// Load popular products at startup
try await preloader.preload(
    [("prod-1", product1), ("prod-2", product2)],
    from: { products in
        // Data source
        products
    }
)

// Products immediately available without network request
let product = cache.get("prod-1")
```

### Preloading Example: Featured Products

```swift
@MainActor
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Warm cache with featured products
        Task {
            let featured = try await api.getFeaturedProducts()
            for product in featured {
                productCache.set(product.id, value: product)
            }
        }
        return true
    }
}
```

## 9. Cache Invalidation Strategies

**Best for**: Deciding when to update cached data

StateKit provides multiple invalidation approaches:

```swift
import StateKitCache

// Immediate invalidation
let cache = LRUCache<String, Product>(capacity: 100)
cache.clear()  // Clear all

cache.remove("prod-123")  // Remove specific key

// Time-based: use TTL cache
let ttlCache = TTLCache<String, Product>(ttl: 300)  // Auto-expires

// Event-based: listen for updates
cache.onEvict { key, _ in
    // Item was evicted - refresh if needed
}
```

### Invalidation Patterns

```swift
// Pattern 1: Invalidate on product update
func updateProduct(_ product: Product) async throws {
    try await api.updateProduct(product)
    productCache.remove(product.id)  // Invalidate
}

// Pattern 2: Batch invalidation
func invalidateCategory(_ category: String) {
    // Remove all products in category
    let keys = productCache.allKeys()
    for key in keys {
        if key.hasPrefix(category) {
            productCache.remove(key)
        }
    }
}

// Pattern 3: Debounced invalidation
let invalidationQueue = DispatchQueue(label: "cache-invalidation")
func scheduleInvalidation(_ key: String, delay: TimeInterval = 1.0) {
    invalidationQueue.asyncAfter(deadline: .now() + delay) {
        cache.remove(key)
    }
}
```

## 10. Memory Pressure Handling

**Best for**: Applications with tight memory constraints

Memory pressure handler reduces cache under constraints:

```swift
import StateKitCache

let cache = LRUCache<String, LargeData>(capacity: 1000)
let pressureHandler = MemoryPressureHandler(cache: cache)

pressureHandler.setThresholds(
    warning: 0.7,    // 70% memory usage triggers warning
    critical: 0.85   // 85% triggers cleanup
)

// Under memory pressure, cache automatically shrinks
// Respects LRU eviction policy while freeing memory
```

## 11. Cache Monitoring & Metrics

**Best for**: Understanding cache performance

Monitor cache efficiency:

```swift
let cache = LRUCache<String, Product>(capacity: 100)
let monitor = CacheMonitor(cache: cache)

// Periodic reporting
Task {
    while !Task.isCancelled {
        let metrics = monitor.report()
        print("Cache hit rate: \(metrics.hitRate * 100)%")
        print("Size: \(metrics.size)/\(metrics.capacity)")
        
        try await Task.sleep(nanoseconds: 60 * 1_000_000_000)  // Every minute
    }
}
```

### Health Checks

```swift
// Monitor cache efficiency
let hitRate = cache.stats.hitRate

if hitRate < 0.5 {
    // Low hit rate - consider larger capacity
}

if hitRate > 0.95 {
    // Very high hit rate - consider smaller capacity to save memory
}

// Check for memory leaks
if cache.stats.size == cache.stats.capacity {
    // Cache full - evictions happening
}
```

## 12. Provider Integration

**Best for**: Reactive caching with Riverpods

Integrate cache with state management:

```swift
import StateKitCache
import Riverpods

let productCacheProvider = Provider<LRUCache<String, Product>> { _ in
    LRUCache(capacity: 100)
}

let productProvider = FutureProvider<String, Product> { ref, productId in
    let cache = ref.watch(productCacheProvider)
    
    if let cached = cache.get(productId) {
        return cached
    }
    
    let product = try await api.getProduct(productId)
    cache.set(productId, value: product)
    return product
}

// Usage
let container = ProviderContainer()
let product = container.read(productProvider("prod-123"))
```

## 13. Common Cache Patterns

### Pattern 1: Multi-Level Cache

```swift
// L1: Hot data (100 items)
let l1Cache = LRUCache<String, Product>(capacity: 100)

// L2: Warm data (1000 items)
let l2Cache = TTLCache<String, Product>(ttl: 3600)

// L3: Disk/DB
func getProduct(_ id: String) async -> Product? {
    // Check L1
    if let hit = l1Cache.get(id) { return hit }
    
    // Check L2
    if let hit = l2Cache.get(id) {
        l1Cache.set(id, value: hit)  // Promote to L1
        return hit
    }
    
    // Check L3 (database)
    if let hit = try await database.get(id) {
        l2Cache.set(id, value: hit)
        return hit
    }
    
    return nil
}
```

### Pattern 2: Stampede Prevention

Prevent multiple simultaneous requests for same data:

```swift
var inFlight: [String: Task<Product, Error>] = [:]

func getProduct(_ id: String) async throws -> Product {
    // If already loading, reuse in-flight request
    if let task = inFlight[id] {
        return try await task.value
    }
    
    let task = Task {
        let product = try await api.getProduct(id)
        cache.set(id, value: product)
        return product
    }
    
    inFlight[id] = task
    defer { inFlight.removeValue(forKey: id) }
    
    return try await task.value
}
```

### Pattern 3: Warming on Sync

Rebuild cache when syncing data:

```swift
func syncProducts() async throws {
    cache.clear()  // Clear stale data
    
    let products = try await api.getAllProducts()
    
    // Warm cache with fresh data
    for product in products {
        cache.set(product.id, value: product)
    }
}
```

## 14. Testing Caches

```swift
import XCTest
import StateKitCache

class CacheTests: XCTestCase {
    func testLRUEviction() {
        let cache = LRUCache<String, Int>(capacity: 2)
        
        cache.set("a", value: 1)
        cache.set("b", value: 2)
        cache.set("c", value: 3)  // Evicts "a"
        
        XCTAssertNil(cache.get("a"))
        XCTAssertNotNil(cache.get("b"))
        XCTAssertNotNil(cache.get("c"))
    }
    
    func testTTLExpiration() async {
        let cache = TTLCache<String, String>(ttl: 0.1)
        cache.set("key", value: "value")
        
        XCTAssertNotNil(cache.get("key"))
        
        try await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds
        
        XCTAssertNil(cache.get("key"))
    }
}
```

## 15. Best Practices

1. **Choose right strategy**: LRU for general, LFU for hot/cold, TTL for time-sensitive
2. **Set appropriate capacity**: Too small = frequent misses, too large = wasted memory
3. **Monitor metrics**: Track hit rates to verify cache effectiveness
4. **Handle eviction**: Set callbacks for cleanup when items removed
5. **Plan invalidation**: Know when and how to refresh data
6. **Concurrent access**: Use @MainActor for thread safety
7. **Test thoroughly**: Verify cache behavior under load
8. **Document TTL**: Clear expiration times prevent confusion

---

# Part 2: Feature Flags & A/B Testing

## 16. Introduction to Feature Flags

Feature flags decouple deployment from release. Deploy code to production without making features visible:

```swift
import StateKitFeatureFlags

// Define feature
let darkModeFlag = FeatureFlag<Bool>(
    name: "dark_mode",
    defaultValue: false
)

// Check in UI
if darkModeFlag.value {
    // Show dark mode
} else {
    // Show light mode
}
```

### Why Feature Flags?

- **Safe deployment**: Deploy incomplete features safely
- **Gradual rollout**: Enable for percentage of users
- **A/B testing**: Compare feature variants
- **Rollback**: Disable broken features instantly
- **Override testing**: Test features locally during development

## 17. Type-Safe Feature Flags

StateKit provides type-safe flags:

```swift
// Boolean flags
let flag1 = FeatureFlag<Bool>(name: "feature_1", defaultValue: false)

// String flags (e.g., service URL)
let flag2 = FeatureFlag<String>(name: "api_host", defaultValue: "api.example.com")

// Integer flags (e.g., request timeout)
let flag3 = FeatureFlag<Int>(name: "timeout_ms", defaultValue: 5000)

// Double flags (e.g., performance multiplier)
let flag4 = FeatureFlag<Double>(name: "cache_hitrate_target", defaultValue: 0.85)
```

### Flag Registry

Centralize flag management:

```swift
let registry = FeatureFlagRegistry()

// Register flags
registry.register(darkModeFlag)
registry.register(newCheckoutFlag)
registry.register(betaFeaturesFlag)

// Check if enabled
if registry.isEnabled("dark_mode") {
    // Feature enabled
}

// Override for testing
registry.override(darkModeFlag, value: true)
registry.clearOverride(darkModeFlag)
```

## 18. Percentage-Based Rollout

Gradually enable features for percentage of users:

```swift
let rollout = PercentageRollout(percentage: 20)

if rollout.isEnabled(for: userId) {
    // Feature enabled for this user (20% chance)
}
```

### Progressive Rollout

```swift
// Day 1: 5% of users
var rollout = PercentageRollout(percentage: 5)

// Day 3: 25% of users
rollout = PercentageRollout(percentage: 25)

// Day 7: 100% of users (fully rolled out)
rollout = PercentageRollout(percentage: 100)
```

## 19. Time-Based Rollout

Enable features at specific times:

```swift
let rollout = TimeBasedRollout(
    enableDate: Date().addingTimeInterval(3600),  // In 1 hour
    disableDate: Date().addingTimeInterval(86400 * 7)  // In 1 week
)

if rollout.isEnabled() {
    // Feature active in time window
}
```

### Use Cases

```swift
// Holiday promotion: Enable for specific dates
let holidayPromo = TimeBasedRollout(
    enableDate: Date(2026, 11, 24),  // Black Friday
    disableDate: Date(2026, 11, 30)   // End of weekend
)

// Beta period: Time-limited feature access
let betaAccess = TimeBasedRollout(
    enableDate: Date(),
    disableDate: Date().addingTimeInterval(86400 * 30)  // 30 days
)
```

## 20. Canary Rollout (Gradual)

Progressively increase rollout percentage over time:

```swift
let canary = CanaryRollout(
    startPercentage: 5,
    endPercentage: 100,
    startDate: Date(),
    endDate: Date().addingTimeInterval(86400 * 7)  // 1 week
)

if canary.isEnabled(for: userId) {
    // Feature enabled for percentage increasing over week
}
```

### Canary Strategy

```
Day 1 (5%):   5   users out of 100 affected
Day 2 (19%):  19  users out of 100 affected
Day 3 (34%):  34  users out of 100 affected
Day 4 (48%):  48  users out of 100 affected
Day 5 (63%):  63  users out of 100 affected
Day 6 (81%):  81  users out of 100 affected
Day 7 (100%): 100 users out of 100 affected (full rollout)
```

### Benefits

- **Early issue detection**: Catches bugs with small user base
- **Reduced impact**: Problems affect few users initially
- **Confidence building**: Team gains confidence as rollout proceeds
- **Easy rollback**: Disable flag if issues emerge

## 21. Staged Rollout

Multi-phase rollout: internal → beta → general release

```swift
let staged = StagedRollout(
    internalUsers: ["eng-1", "eng-2", "eng-3"],
    betaUsers: ["beta-user-1", "beta-user-2"],
    generalReleaseDate: Date().addingTimeInterval(86400 * 3)
)

if staged.isEnabled(for: userId) {
    // Feature available for user's stage
}
```

### Rollout Phases

```
Phase 1: Internal (Engineers)
├─ Duration: 1-2 days
├─ Users: 3-5 team members
└─ Goal: Verify no obvious bugs

Phase 2: Beta (Power Users)
├─ Duration: 2-3 days
├─ Users: 20-100 beta users
└─ Goal: Find edge cases, gather feedback

Phase 3: General (All Users)
├─ Duration: Ongoing
├─ Users: 100% of user base
└─ Goal: Monitor production metrics
```

## 22. A/B Testing Framework

Compare feature variants with deterministic user assignment:

```swift
import StateKitFeatureFlags

let test = ABTest(
    name: "checkout_ui_test",
    hypothesis: "New checkout increases conversion by 15%",
    variants: [
        ABTestVariant(name: "control", value: false, weight: 50),
        ABTestVariant(name: "treatment", value: true, weight: 50)
    ]
)

// Assign user to variant (deterministic per user)
let variant = test.assignUser(userId)

if variant {
    // Show new checkout
} else {
    // Show control checkout
}
```

### Deterministic Assignment

Same user always gets same variant:

```swift
let test = ABTest(...)

// User 123 always gets same variant
let variant1 = test.assignUser("user-123")
let variant2 = test.assignUser("user-123")
assert(variant1 == variant2)  // True - deterministic
```

### Multi-Variant Testing

```swift
let colorTest = ABTest(
    name: "button_color",
    variants: [
        ABTestVariant(name: "blue", value: "blue", weight: 25),
        ABTestVariant(name: "green", value: "green", weight: 25),
        ABTestVariant(name: "red", value: "red", weight: 25),
        ABTestVariant(name: "purple", value: "purple", weight: 25)
    ]
)

let buttonColor = colorTest.assignUser(userId)
```

## 23. Conversion Tracking

Record experiment results:

```swift
let runner = ABTestRunner(test: checkoutTest)

// Track purchase as conversion
runner.recordConversion(userId: "user-123", value: 99.99)

// Check results
let results = runner.results
print("Conversions: \(results.conversions)")
print("Revenue: \(results.totalValue)")
```

### Tracking Multiple Events

```swift
let runner = ABTestRunner(test: signupTest)

// Day 1: User signs up (primary conversion)
runner.recordConversion(userId: "user-123", value: 1)

// Day 3: User upgrades (secondary conversion)  
runner.recordConversion(userId: "user-123", value: 2)
```

## 24. Statistical Significance Testing

Validate that improvements are real, not random:

```swift
let test = ABTest(...)

// Simulate results
let controlConversions = 45
let controlTotal = 1000

let treatmentConversions = 62
let treatmentTotal = 1000

let statisticalTest = StatisticalTest(
    controlConversions: controlConversions,
    controlTotal: controlTotal,
    treatmentConversions: treatmentConversions,
    treatmentTotal: treatmentTotal
)

if statisticalTest.isSignificant(alpha: 0.05) {
    print("Result is statistically significant!")
    print("Improvement: \(String(format: "%.1f", statisticalTest.improvementPercent))%")
} else {
    print("Result is not statistically significant - need more data")
}
```

### Understanding Significance

- **p-value < 0.05**: 95% confidence improvement is real
- **p-value < 0.01**: 99% confidence improvement is real
- **p-value > 0.05**: Not enough evidence - continue test

## 25. Multiple Test Coordination

Run several A/B tests simultaneously:

```swift
let testManager = ABTestManager()

// Register multiple tests
testManager.registerTest(checkoutTest)
testManager.registerTest(colorTest)
testManager.registerTest(analyticsTest)

// Track conversions across tests
testManager.recordConversion(userId: "user-123", testName: "checkout_ui_test", value: 99.99)
testManager.recordConversion(userId: "user-123", testName: "button_color", value: 1)

// Get results
let allResults = testManager.allResults
```

### Avoiding Interactions

When running multiple tests, watch for interactions:

```
Test A (25% treatment): Feature A enabled/disabled
Test B (25% treatment): Feature B enabled/disabled

Risk: Users get both features (25% × 25% = 6.25%)
      Users get neither (75% × 75% = 56.25%)
      Users get only A (25% × 75% = 18.75%)
      Users get only B (75% × 25% = 18.75%)

Solution: Orthogonal splitting - ensure tests are independent
```

## 26. Override Support (Local Testing)

Override flags during development:

```swift
let registry = FeatureFlagRegistry()

// In production: Read from server
// let value = registry.getValue(flag)

// During testing: Override locally
registry.override(newCheckoutFlag, value: true)

// Now flag always returns true
assert(registry.isEnabled("new_checkout") == true)

// Clear override when done testing
registry.clearOverride(newCheckoutFlag)
```

### Device-Specific Overrides

```swift
#if DEBUG
let registry = FeatureFlagRegistry()
registry.override(darkModeFlag, value: true)  // Debug build uses dark mode
#endif
```

## 27. Feature Flag Naming Convention

Clear names prevent confusion:

```swift
// Good names
let shouldShowNewUI = FeatureFlag<Bool>(name: "show_new_ui", ...)
let maxRetries = FeatureFlag<Int>(name: "max_retries", ...)
let apiEndpoint = FeatureFlag<String>(name: "api_endpoint", ...)

// Avoid ambiguous names
// let flag = FeatureFlag<Bool>(name: "feature", ...)  // Too generic
// let enabled = FeatureFlag<Bool>(name: "enabled", ...)  // Unclear what
```

## 28. Common Feature Flag Patterns

### Pattern 1: Kill Switch

Instantly disable broken feature:

```swift
let emergencyKillSwitch = FeatureFlag<Bool>(
    name: "checkout_enabled",
    defaultValue: true
)

if !emergencyKillSwitch.value {
    showError("Checkout temporarily unavailable")
    return
}
```

### Pattern 2: Deprecation

Gradually remove old code:

```swift
let useNewAlgorithm = FeatureFlag<Bool>(name: "use_new_search_algorithm", defaultValue: false)

func search(_ query: String) -> [Result] {
    if useNewAlgorithm.value {
        return newSearch(query)
    } else {
        return legacySearch(query)  // Eventually remove
    }
}
```

### Pattern 3: Capacity Gates

Limit feature based on load:

```swift
let maxConcurrentAnalytics = FeatureFlag<Int>(name: "max_analytics_connections", defaultValue: 100)

if analyticsConnections < maxConcurrentAnalytics.value {
    analytics.startTracking()
} else {
    // Too much load, disable analytics temporarily
}
```

## 29. Testing Feature Flags

```swift
import XCTest
import StateKitFeatureFlags

class FeatureFlagTests: XCTestCase {
    func testABTestAssignmentIsDeterministic() {
        let test = ABTest(
            name: "test",
            variants: [
                ABTestVariant(name: "a", value: 1, weight: 50),
                ABTestVariant(name: "b", value: 2, weight: 50)
            ]
        )
        
        let variant1 = test.assignUser("user-1")
        let variant2 = test.assignUser("user-1")
        
        XCTAssertEqual(variant1, variant2)
    }
    
    func testCanaryRollout() {
        let canary = CanaryRollout(
            startPercentage: 0,
            endPercentage: 100,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400)
        )
        
        XCTAssert(canary.isEnabled(for: "user-1"))
    }
}
```

## 30. Best Practices

1. **Name clearly**: Flag names should indicate purpose
2. **Document hypothesis**: What are you trying to learn?
3. **Set duration**: Know when to end experiments
4. **Monitor metrics**: Track both primary and secondary metrics
5. **Isolation**: Ensure tests don't interfere with each other
6. **Sample size**: Ensure sufficient data for significance
7. **Ethical testing**: Disclose when testing major features
8. **Cleanup**: Remove old flags that are 100% rolled out

---

# Part 3: Analytics & User Journey

## 31. Introduction to Analytics

Analytics transforms user behavior into insights:

- **Understanding**: What do users actually do?
- **Optimization**: Which changes improve metrics?
- **Debugging**: Where do users abandon?
- **Planning**: What features matter most?

StateKit provides structured event tracking.

## 32. Event Tracking Basics

Record user actions:

```swift
import StateKitAnalytics

let tracker = EventTracker()

// Track simple events
tracker.track("button_tapped", properties: ["button_id": .string("purchase")])

// Track with structured properties
tracker.track("purchase", properties: [
    "value": .double(99.99),
    "items": .int(3),
    "currency": .string("USD")
])
```

### Property Types

```swift
// Codable values
tracker.track("event", properties: [
    "bool_prop": .bool(true),
    "int_prop": .int(42),
    "double_prop": .double(3.14),
    "string_prop": .string("hello"),
    "array_prop": .array([.int(1), .int(2), .int(3)]),
    "dict_prop": .dictionary(["key": .string("value")])
])
```

## 33. Standard Events

StateKit provides common event names:

```swift
tracker.track(StandardEvent.appLaunched)
tracker.track(StandardEvent.appForegrounded)
tracker.track(StandardEvent.appBackgrounded)
tracker.track(StandardEvent.userSignedIn, properties: ["provider": .string("google")])
tracker.track(StandardEvent.userSignedOut)
tracker.track(StandardEvent.screenViewed, properties: ["screen": .string("home")])
tracker.track(StandardEvent.buttonTapped, properties: ["button": .string("buy")])
tracker.track(StandardEvent.errorOccurred, properties: [
    "code": .int(500),
    "message": .string("Server error")
])
```

## 34. User Sessions

Track user sessions and activity:

```swift
let journey = UserJourneyTracker()

// Start new session
journey.startNewSession(properties: [
    "source": .string("app_store"),
    "version": .string("2.6.0")
])

// Record events in session
journey.recordEvent(AnalyticsEvent(
    name: "product_viewed",
    properties: ["product_id": .string("prod-123")],
    userId: "user-1"
))

// Get session info
if let sessionId = journey.currentSessionId {
    let events = journey.journey(sessionId: sessionId)
    print("Events in session: \(events.count)")
}

// End session
journey.endSession()
```

### Session Duration

```swift
let session = journey.allSessions.first!
if let duration = session.duration {
    print("Session lasted \(duration) seconds")
}
```

## 35. Event Batching & Flushing

Optimize network usage by batching events:

```swift
let config = AnalyticsConfig(
    enabled: true,
    flushInterval: 30,      // Flush every 30 seconds
    batchSize: 50           // Or when 50 events accumulated
)

let tracker = EventTracker(config: config)

// Set flush handler
tracker.onFlush { events in
    // Send to backend
    api.sendAnalytics(events)
}

// Events automatically batch and flush
tracker.track("event1")
tracker.track("event2")
// ... more events ...
// Automatically flushed when batch size reached or time elapsed
```

## 36. Funnel Analysis

Track conversion through stages:

```swift
let funnel = [
    FunnelAnalyzer.FunnelStep(name: "View", eventName: "product_viewed", index: 0),
    FunnelAnalyzer.FunnelStep(name: "Add", eventName: "item_added", index: 1),
    FunnelAnalyzer.FunnelStep(name: "Checkout", eventName: "checkout_started", index: 2),
    FunnelAnalyzer.FunnelStep(name: "Purchase", eventName: "purchase_completed", index: 3),
]

let analyzer = FunnelAnalyzer(steps: funnel)
let result = analyzer.analyze(events: allEvents)

print("View: 1000 users")
print("Add: \(result.conversionRates[1] * 100)%")
print("Checkout: \(result.conversionRates[2] * 100)%")
print("Purchase: \(result.conversionRates[3] * 100)%")
```

### Interpreting Funnels

```
Funnel (Ideal e-commerce):
View Product:     100%  (all users)
Add to Cart:      40%   (good engagement)
Start Checkout:   80%   (small abandonment)
Complete Purchase: 75%  (5% checkout abandonment)

Conversion Rate: 75% complete purchase from view
```

## 37. Drop-off Analysis

Identify where users abandon:

```swift
let dropoffAnalyzer = DropoffAnalyzer(funnel: [
    "product_viewed",
    "item_added",
    "checkout_started",
    "purchase_completed"
])

let dropoffs = dropoffAnalyzer.analyzeDropoff(events: events)

for (step, users) in dropoffs.sorted(by: { $0.value > $1.value }) {
    print("\(step): \(users) users")
}

// Identify critical drop-off points
let shopToCheckout = dropoffAnalyzer.dropoffRate(
    events: events,
    from: "item_added",
    to: "checkout_started"
)

if shopToCheckout > 0.3 {
    // 30% drop between shopping and checkout - investigate!
}
```

## 38. Cohort Analysis

Understand retention by signup cohort:

```swift
let cohortAnalyzer = CohortAnalyzer()
let cohorts = cohortAnalyzer.analyzeCohorts(
    events: events,
    onEvent: "app_launched"
)

for cohort in cohorts {
    print("Week of \(cohort.weekStarting):")
    print("  Size: \(cohort.size) users")
    for (week, rate) in cohort.retentionByWeek.enumerated() {
        print("  Week \(week): \(String(format: "%.0f", rate * 100))% retained")
    }
}
```

### Reading Cohort Data

```
Week 1 (Jan 1):  Cohort size: 1000
  Week 0: 100% (everyone in cohort)
  Week 1: 40%  (400 active users 1 week later)
  Week 2: 25%  (250 active users 2 weeks later)
  Week 3: 15%  (150 active users 3 weeks later)

Week 2 (Jan 8):  Cohort size: 1200
  Week 0: 100%
  Week 1: 45%  (stronger retention than week 1 cohort)
  Week 2: 28%
  Week 3: 17%
```

## 39. Event Filtering & Analysis

Filter events for specific analysis:

```swift
let filter = EventFilter(events: allEvents)

// Filter by event type
let purchases = filter.byName("purchase_completed")

// Filter by user
let userEvents = filter.byUser("user-123")

// Filter by date range
let todayEvents = filter.byDate(
    from: Date().startOfDay,
    to: Date()
)

// Filter by property value
let freeUsers = filter.byProperty("plan", value: .string("free"))
```

### Combining Filters

```swift
let purchases = filter.byName("purchase_completed")
let freeTierPurchases = purchases.filter { event in
    event.properties["plan"] == .string("free")
}

print("Free users who purchased: \(freeTierPurchases.count)")
```

## 40. Event Logging & Export

Export events for external analysis:

```swift
let logger = EventLogger(tracker: tracker)

// Get JSON representation
let jsonString = logger.logEvents()
try? FileManager.default.writeJSON(jsonString, to: "events.json")

// Get event summary
let summary = logger.summary()
for (name, count) in summary {
    print("\(name): \(count)")
}
```

## 41. Provider Observation

Automatically track state changes:

```swift
import Riverpods
import StateKitAnalytics

let userProvider = Atom(initialValue: User?)

// Create observer
let analyticsObserver = AnalyticsProviderObserver(
    tracker: tracker,
    includeValues: false  // Don't log sensitive user data
)

// Register observer
container.addObserver(analyticsObserver)

// Now every state change is tracked as "state_changed" event
let newUser = User(...)
container.write(userProvider, newUser)
// Auto-tracked: AnalyticsEvent(name: "state_changed", ...)
```

## 42. User Segmentation

Analyze by user segment:

```swift
// Segment by plan
let freePlan = events.filter { event in
    event.properties["plan"] == .string("free")
}

let proPlan = events.filter { event in
    event.properties["plan"] == .string("pro")
}

// Calculate metrics per segment
let freeConversion = freePlan.filter { $0.name == "purchase_completed" }.count
let freeTotal = Set(freePlan.map { $0.userId }).count

print("Free tier conversion: \(Double(freeConversion) / Double(freeTotal) * 100)%")
```

## 43. Custom Event Properties

Define domain-specific properties:

```swift
// E-commerce events
tracker.track("product_viewed", properties: [
    "product_id": .string("prod-123"),
    "category": .string("electronics"),
    "price": .double(299.99),
    "stock": .int(15)
])

// User onboarding events
tracker.track("signup_complete", properties: [
    "email": .string("user@example.com"),
    "source": .string("instagram_ad"),
    "plan": .string("pro"),
    "trial_days": .int(14)
])

// Performance events
tracker.track("api_call", properties: [
    "endpoint": .string("/products"),
    "duration_ms": .double(145.5),
    "status_code": .int(200)
])
```

## 44. Analytics Configuration

Customize tracking behavior:

```swift
let config = AnalyticsConfig(
    enabled: true,
    flushInterval: 30,      // 30 seconds between flushes
    batchSize: 50,          // Flush when 50 events accumulated
    persistLocal: false,    // Don't persist to disk
    userId: "user-123",     // Default user ID
    sessionId: UUID().uuidString  // Session identifier
)

let tracker = EventTracker(config: config)
```

### Disabling in Debug Builds

```swift
#if DEBUG
let config = AnalyticsConfig(enabled: false)  // Disable during development
#else
let config = AnalyticsConfig(enabled: true)
#endif
```

## 45. Testing Analytics

```swift
import XCTest
import StateKitAnalytics

class AnalyticsTests: XCTestCase {
    func testEventTracking() {
        let tracker = EventTracker()
        
        tracker.track("test_event")
        
        XCTAssertEqual(tracker.eventCount, 1)
        XCTAssertEqual(tracker.allEvents.first?.name, "test_event")
    }
    
    func testFunnelAnalysis() {
        let events = [
            AnalyticsEvent(name: "view", userId: "user-1"),
            AnalyticsEvent(name: "add", userId: "user-1"),
            AnalyticsEvent(name: "buy", userId: "user-1"),
        ]
        
        let funnel = FunnelAnalyzer(steps: [
            FunnelAnalyzer.FunnelStep(name: "View", eventName: "view", index: 0),
            FunnelAnalyzer.FunnelStep(name: "Add", eventName: "add", index: 1),
            FunnelAnalyzer.FunnelStep(name: "Buy", eventName: "buy", index: 2),
        ])
        
        let result = funnel.analyze(events: events)
        XCTAssertEqual(result.conversionRates.first, 1.0)  // 100% reached view
    }
}
```

---

# Advanced Patterns

## 46. Combining Cache & Analytics

Track cache performance metrics:

```swift
import StateKitCache
import StateKitAnalytics

@MainActor
class InstrumentedCache<Key: Hashable, Value> {
    private let cache: LRUCache<Key, Value>
    private let tracker: EventTracker
    
    init(capacity: Int, tracker: EventTracker) {
        self.cache = LRUCache(capacity: capacity)
        self.tracker = tracker
    }
    
    func get(_ key: Key) -> Value? {
        if let value = cache.get(key) {
            // Track cache hit
            tracker.track("cache_hit", properties: [
                "cache_type": .string("lru"),
                "hitRate": .double(cache.stats.hitRate)
            ])
            return value
        } else {
            // Track cache miss
            tracker.track("cache_miss")
            return nil
        }
    }
    
    func set(_ key: Key, value: Value) {
        cache.set(key, value: value)
        tracker.track("cache_set")
    }
}
```

## 47. Feature Flags with Analytics

Analyze A/B test results through analytics:

```swift
let test = ABTest(name: "checkout_test", ...)

// Track variant assignment
tracker.track("experiment_assigned", properties: [
    "experiment": .string(test.name),
    "variant": .string(test.assignUser(userId) ? "treatment" : "control")
])

// Track conversions
tracker.track("purchase", properties: [
    "experiment": .string(test.name),
    "value": .double(amount)
])

// Later: analyze purchase events by experiment variant
```

## 48. Multi-Tenant Analytics

Handle multiple organizations:

```swift
let config = AnalyticsConfig(
    userId: currentUser.id,
    sessionId: currentSession.id
)

let tracker = EventTracker(config: config)

// All events include user context
tracker.track("event", properties: [
    "tenant_id": .string(currentTenant.id),
    "user_id": .string(currentUser.id),
    "organization": .string(currentTenant.name)
])
```

## 49. Privacy-First Analytics

Minimize collected personal data:

```swift
// Good: Anonymize user identifiers
let config = AnalyticsConfig(
    userId: hashUserId(currentUser.id),  // Hash instead of raw ID
    sessionId: UUID().uuidString
)

// Good: Don't track sensitive properties
tracker.track("signup", properties: [
    // Include: conversion data
    "plan": .string("pro"),
    // Exclude: personal data
    // "email": .string(user.email),
    // "phone": .string(user.phone),
])
```

## 50. Real-World Example: Ecommerce Analytics

```swift
@MainActor
class EcommerceAnalytics {
    private let tracker: EventTracker
    private let journey: UserJourneyTracker
    
    init() {
        self.tracker = EventTracker()
        self.journey = UserJourneyTracker()
    }
    
    func trackProductView(_ product: Product) {
        tracker.track("product_viewed", properties: [
            "product_id": .string(product.id),
            "category": .string(product.category),
            "price": .double(product.price)
        ])
    }
    
    func trackAddToCart(_ product: Product, quantity: Int) {
        tracker.track("item_added", properties: [
            "product_id": .string(product.id),
            "quantity": .int(quantity),
            "price": .double(product.price)
        ])
    }
    
    func trackCheckoutStart(cartValue: Double) {
        tracker.track("checkout_started", properties: [
            "cart_value": .double(cartValue)
        ])
    }
    
    func trackPurchase(_ order: Order) {
        tracker.track("purchase_completed", properties: [
            "order_id": .string(order.id),
            "total": .double(order.total),
            "items": .int(order.items.count),
            "payment_method": .string(order.paymentMethod)
        ])
    }
    
    func analyzeConversion() {
        let funnel = FunnelAnalyzer(steps: [
            FunnelAnalyzer.FunnelStep(name: "View", eventName: "product_viewed", index: 0),
            FunnelAnalyzer.FunnelStep(name: "Add", eventName: "item_added", index: 1),
            FunnelAnalyzer.FunnelStep(name: "Checkout", eventName: "checkout_started", index: 2),
            FunnelAnalyzer.FunnelStep(name: "Purchase", eventName: "purchase_completed", index: 3),
        ])
        
        let result = funnel.analyze(events: tracker.allEvents)
        
        print("Funnel Analysis:")
        for (index, step) in result.steps.enumerated() {
            let rate = result.conversionRates[index]
            print("  \(step.name): \(String(format: "%.1f", rate * 100))%")
        }
    }
}
```

---

## Summary

StateKit's extended features provide production-ready utilities for:

- **Performance**: Advanced caching strategies (LRU, LFU, TTL)
- **Safety**: Feature flags with gradual rollouts and A/B testing
- **Understanding**: Analytics with funnel and cohort analysis

These modules integrate seamlessly with StateKit's core state management, providing a complete framework for building production applications.

---

**Total Pages**: 50+  
**Code Examples**: 100+  
**Best Practices**: 30+  
**Production Patterns**: 15+

**Version**: 2.6.0-beta  
**Last Updated**: May 17, 2026
