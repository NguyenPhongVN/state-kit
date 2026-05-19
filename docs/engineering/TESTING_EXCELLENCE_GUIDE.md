# Testing Excellence Guide - Phase 4 (Post-V1)

**Version**: 2.3.0-beta  
**Date**: May 17, 2026  
**Status**: In Development

---

## Overview

Phase 4 delivers a comprehensive testing framework for StateKit with:
- **Test Fixtures** - Pre-built test data generators
- **Integration Testing** - Multi-feature test suites
- **Deterministic Testing** - 100% reproducible tests
- **Performance Testing** - Measure and compare implementations

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Test Fixtures](#test-fixtures)
3. [Integration Testing](#integration-testing)
4. [Deterministic Testing](#deterministic-testing)
5. [Performance Testing](#performance-testing)
6. [Best Practices](#best-practices)
7. [Examples](#examples)

---

## Quick Start

### Basic Fixture Usage

```swift
import StateKitTesting

// Generate test data
let generator = StateGenerator()
let randomInt = generator.randomInt(min: 0, max: 100)
let randomString = generator.randomString(length: 10)
let randomArray = generator.randomArray(count: 5) { generator.randomInt() }

// Build test data
let user = TestDataBuilder(base: defaultUser)
    .set(\.name, to: "John")
    .set(\.email, to: "john@example.com")
    .build()
```

### Integration Test

```swift
final class ShoppingIntegrationTests: MultiFeatureTestSuite {
    func testCheckout() async {
        let env = testEnvironment
        let container = env.build()

        // Perform actions
        let notifier = container.read(shoppingProvider.notifier)
        notifier.addItem(product)

        // Assert state
        let state = container.read(shoppingProvider)
        XCTAssertEqual(state.items.count, 1)
    }
}
```

### Deterministic Testing

```swift
let env = DeterministicTestEnvironment(seed: 42)
env.freezeTime(to: Date(timeIntervalSince1970: 0))

// All randomness and timing is now deterministic
let random1 = Int.random(in: 0..<100)  // Always same value
let time = env.now()  // Always same time
```

---

## Test Fixtures

### StateGenerator

Generate random test data:

```swift
let generator = StateGenerator()

// Integers
let count = generator.randomInt(min: 1, max: 10)

// Doubles
let price = generator.randomDouble(min: 0, max: 100)

// Strings
let name = generator.randomString(length: 20)

// Booleans
let flag = generator.randomBool()

// Dates
let date = generator.randomDate()

// Arrays
let items = generator.randomArray(count: 5) {
    generator.randomInt()
}
```

### TestDataBuilder

Build test data with fluent API:

```swift
var builder = TestDataBuilder(base: defaultUser)
    .set(\.name, to: "John")
    .set(\.email, to: "john@example.com")
    .set(\.age, to: 30)
    .modify { user in
        user.isActive = true
    }

let user = builder.build()
```

### Fixture Registry

Register and reuse fixtures:

```swift
let registry = FixtureRegistry()

// Register fixtures
registry.register("admin_user") {
    User(id: 1, role: .admin)
}

registry.register("regular_user") {
    User(id: 2, role: .user)
}

// Retrieve fixtures
let admin = registry.get("admin_user")
let user = registry.get("regular_user")

// List all
let keys = registry.allKeys()
```

### Parameterized Fixtures

Create multiple variations:

```swift
let userRoles = ParameterizedFixture<User>(
    parameters: [
        ("admin", User(role: .admin)),
        ("user", User(role: .user)),
        ("guest", User(role: .guest))
    ]
)

// Get specific
if let admin = userRoles.get("admin") {
    // Test admin user
}

// Test all
for (name, user) in userRoles.all() {
    testWithUser(user)
}
```

---

## Integration Testing

### Multi-Feature Test Suite

```swift
final class AuthAndShoppingTests: MultiFeatureTestSuite {
    func testLoginAndShop() async {
        // Setup
        let env = testEnvironment
        let container = env.build()

        // Login
        let authNotifier = container.read(authProvider.notifier)
        await authNotifier.login("user@example.com", "password")

        // Shop
        let shoppingNotifier = container.read(shoppingProvider.notifier)
        shoppingNotifier.addItem(product)

        // Assert interaction
        assertStateConsistency(
            provider: userProvider,
            expectedValue: loggedInUser,
            container: container
        )
    }
}
```

### Test Scenario Builder

```swift
var scenario = TestScenarioBuilder("Complete Checkout")
    .given { env in
        // Setup initial state
    }
    .when { container in
        // Perform actions
        let notifier = container.read(checkoutProvider.notifier)
        await notifier.checkout()
    }
    .then { container in
        // Verify results
        let state = container.read(appProvider)
        XCTAssertTrue(state.orderConfirmed)
    }

await scenario.run()
```

### Feature Test Harness

```swift
let harness = FeatureTestHarness(
    name: "Shopping",
    buildProvider: { shoppingProvider }
)

// Test isolated feature
let initialState = harness.currentState
XCTAssertTrue(initialState.items.isEmpty)

// Generate report
let report = harness.generateReport()
print(report)
```

---

## Deterministic Testing

### Frozen Time

```swift
let env = DeterministicTestEnvironment()
env.freezeTime(to: Date(timeIntervalSince1970: 0))

// Time doesn't change
let time1 = env.now()
let time2 = env.now()
XCTAssertEqual(time1, time2)

// Advance time manually
env.advance(by: 3600)  // 1 hour later
let laterTime = env.now()
```

### Seeded Random Numbers

```swift
var rng1 = DeterministicRandom(seed: 42)
let random1 = rng1.nextInt(min: 0, max: 100)

var rng2 = DeterministicRandom(seed: 42)
let random2 = rng2.nextInt(min: 0, max: 100)

// Same seed = same random numbers
XCTAssertEqual(random1, random2)
```

### Execution Records

```swift
let record = TestExecutionRecord()

record.logEvent("started")
record.logEvent("loaded data")
record.logEvent("rendered UI")
record.logEvent("completed")

// Verify sequence
record.verify(["started", "loaded data", "rendered UI", "completed"])

// Generate report
print(record.report())
```

### State Mutation Trace

```swift
var trace = StateMutationTrace(initialState: 0)

trace.record(from: 0, to: 5, action: "add(5)")
trace.record(from: 5, to: 8, action: "add(3)")
trace.record(from: 8, to: 0, action: "reset")

// Verify mutations
XCTAssertTrue(trace.contains(action: "add(5)"))
XCTAssertEqual(trace.path, [0, 5, 8, 0])
XCTAssertEqual(trace.count, 3)
```

---

## Performance Testing

### Measure Execution Time

```swift
let (result, duration) = await PerformanceTesting.measureTime {
    await performExpensiveOperation()
}

print("Operation took \(duration) seconds")
XCTAssertLessThan(duration, 1.0)  // Must complete in under 1 second
```

### Compare Implementations

```swift
let comparison = await PerformanceTesting.comparePerformance(
    name1: "Algorithm A",
    action1: { await algorithmA() },
    name2: "Algorithm B",
    action2: { await algorithmB() }
)

print(comparison)
// Output: Algorithm B is 2.5x faster
```

### Measure Memory

```swift
let (result, memoryUsed) = await PerformanceTesting.measureMemory {
    await createLargeState()
}

print("Operation used \(memoryUsed) bytes")
```

---

## Best Practices

### 1. Use Fixtures for Consistency

```swift
// Good - reusable fixtures
let user = commonFixture.defaultUser
let product = commonFixture.sampleProduct

// Avoid - creating data inline
let user = User(id: 1, name: "Test", email: "test@example.com")
```

### 2. Test Feature Interactions

```swift
// Test how features work together
final class FeatureInteractionTests: MultiFeatureTestSuite {
    func testAuthAffectsCart() async {
        // Verify that authentication state affects shopping
    }
}
```

### 3. Make Tests Deterministic

```swift
// Good - deterministic
let env = DeterministicTestEnvironment(seed: 42)

// Avoid - non-deterministic
let randomValue = Int.random(in: 0..<100)
```

### 4. Document Scenarios

```swift
// Good - clear intent
var scenario = TestScenarioBuilder("User logs in and shops")
    .given { /* setup */ }
    .when { /* actions */ }
    .then { /* assertions */ }

// Avoid - unclear
func test() { /* unclear what's being tested */ }
```

### 5. Verify Consistency

```swift
// Assert that related state stays consistent
assertStateConsistency(
    provider: userProvider,
    expectedValue: currentUser,
    container: container
)
```

---

## Examples

### Example 1: Complete Feature Test

```swift
final class ShoppingFeatureTests: MultiFeatureTestSuite {
    func testAddToCart() async {
        let env = testEnvironment
        let container = env.build()

        // Create product
        let product = TestDataBuilder(base: defaultProduct)
            .set(\.price, to: 9.99)
            .build()

        // Add to cart
        let notifier = container.read(shoppingProvider.notifier)
        notifier.addItem(product)

        // Verify
        let state = container.read(shoppingProvider)
        XCTAssertEqual(state.items.count, 1)
        XCTAssertEqual(state.total, 9.99)
    }
}
```

### Example 2: Integration Test

```swift
final class AuthShoppingIntegrationTests: MultiFeatureTestSuite {
    func testLoggedInUserCanShop() async {
        let env = testEnvironment
        let container = env.build()

        // Setup: Login
        let authNotifier = container.read(authProvider.notifier)
        await authNotifier.login("user@example.com", "password")

        // Action: Shop
        let shoppingNotifier = container.read(shoppingProvider.notifier)
        let product = commonFixture.defaultProduct
        shoppingNotifier.addItem(product)

        // Assert: User is logged in and has cart
        let authState = container.read(authProvider)
        let shoppingState = container.read(shoppingProvider)

        XCTAssertTrue(authState.isAuthenticated)
        XCTAssertEqual(shoppingState.items.count, 1)
    }
}
```

### Example 3: Performance Test

```swift
final class PerformanceTests: XCTestCase {
    func testCheckoutPerformance() async {
        let cart = (0..<100).map { _ in defaultProduct }

        let (_, duration) = await PerformanceTesting.measureTime {
            // Perform checkout with 100 items
            let container = ProviderContainer()
            let notifier = container.read(checkoutProvider.notifier)
            await notifier.checkout()
        }

        // Should complete in under 100ms
        XCTAssertLessThan(duration, 0.1)
    }
}
```

---

## Assertion Helpers

### Verify State Consistency

```swift
// Assert that two related providers have consistent values
assertStateConsistency(
    provider: userProvider,
    expectedValue: currentUser,
    container: container,
    message: "User state should match auth state"
)
```

### Verify Determinism

```swift
// Ensure operation produces same result every time
DeterministicAssertions.assertDeterministic(seed: 42) {
    complexOperation()
}
```

### Verify Reproducibility

```swift
// Ensure operation is reproducible with same seed
DeterministicAssertions.assertReproducible(seed: 42) { seed in
    operationWithSeed(seed)
}
```

---

## Common Test Patterns

### Pattern 1: Fixture-Based Testing

```swift
let fixtures = ParameterizedFixture<User>(
    parameters: [
        ("admin", adminUser),
        ("user", normalUser),
        ("guest", guestUser)
    ]
)

for (role, user) in fixtures.all() {
    testFeatureWith(user: user)
}
```

### Pattern 2: Scenario Testing

```swift
let scenarios = [
    "user_login_and_shop",
    "user_login_and_checkout",
    "guest_browsing"
]

for scenario in scenarios {
    testScenario(named: scenario)
}
```

### Pattern 3: Property-Based Testing

```swift
for _ in 0..<100 {
    let randomUser = commonFixture.randomUser()
    testPropertyWith(user: randomUser)
}
```

---

## References

- [TESTING_EXCELLENCE_GUIDE.md](TESTING_EXCELLENCE_GUIDE.md) - This guide
- [ARCHITECTURE_GUIDE.md](ARCHITECTURE_GUIDE.md) - Architecture patterns
- [DEVTOOLS_GUIDE.md](DEVTOOLS_GUIDE.md) - Testing with DevTools

---

**Version**: 2.3.0-beta  
**Status**: In Development  
**Last Updated**: May 17, 2026  
**Next**: Advanced features and examples
