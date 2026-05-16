# StateKit Feature Module Templates

**Version**: 2.0.0  
**Date**: May 2026  
**Purpose**: Copy-paste templates for creating new feature modules

---

## Quick Start

Choose a template based on your feature complexity:

- **Simple Feature**: Basic state with a notifier
- **Complex Feature**: Multiple notifiers and providers
- **Async Feature**: Async operations and loading states
- **Composed Feature**: Composes multiple substates

---

## Template 1: Simple Feature (Recommended for New Features)

Use this for straightforward features with a single notifier.

### 1. Create Module Directory

```bash
mkdir -p Sources/MyFeature/{Models,Notifiers,Providers,Views,Composition,Tests}
```

### 2. Models/MyState.swift

```swift
import Foundation

/// Represents the state for MyFeature.
struct MyState: Sendable {
    var items: [Item] = []
    var selectedItem: Item?
    var isLoading = false
    var error: MyError?

    // Helper computed property
    var isEmpty: Bool {
        items.isEmpty
    }
}

/// Represents an individual item in MyFeature.
struct Item: Identifiable, Sendable {
    let id: Int
    let name: String
    let description: String
}

/// Errors that can occur in MyFeature.
enum MyError: Error, Sendable, CustomStringConvertible {
    case loadingFailed
    case invalidInput(String)
    case networkError

    var description: String {
        switch self {
        case .loadingFailed:
            return "Failed to load items"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .networkError:
            return "Network error occurred"
        }
    }
}
```

### 3. Notifiers/MyNotifier.swift

```swift
import Foundation
import Riverpods

/// Manages state and logic for MyFeature.
@MainActor
@Observable
open class MyNotifier: Notifier<MyState> {
    // MARK: - Lifecycle

    override func build() -> MyState {
        // Initialize any watchers
        // Load initial data if needed
        return MyState()
    }

    // MARK: - Load Operations

    /// Loads items from the data source.
    func loadItems() async {
        state.isLoading = true
        state.error = nil

        do {
            // Simulate async load
            try await Task.sleep(nanoseconds: 1_000_000_000)
            state.items = [
                Item(id: 1, name: "Item 1", description: "First item"),
                Item(id: 2, name: "Item 2", description: "Second item"),
            ]
            state.isLoading = false
        } catch {
            state.error = .loadingFailed
            state.isLoading = false
        }
    }

    // MARK: - Item Selection

    /// Selects an item.
    ///
    /// - Parameter item: The item to select
    func selectItem(_ item: Item) {
        state.selectedItem = item
    }

    /// Clears the selection.
    func clearSelection() {
        state.selectedItem = nil
    }

    // MARK: - Item Management

    /// Adds a new item.
    ///
    /// - Parameter item: The item to add
    func addItem(_ item: Item) {
        state.items.append(item)
    }

    /// Removes an item by ID.
    ///
    /// - Parameter id: The ID of the item to remove
    func removeItem(withId id: Int) {
        state.items.removeAll { $0.id == id }
        if state.selectedItem?.id == id {
            state.selectedItem = nil
        }
    }

    /// Updates an existing item.
    ///
    /// - Parameters:
    ///   - id: The ID of the item to update
    ///   - updatedItem: The updated item
    func updateItem(withId id: Int, to updatedItem: Item) {
        if let index = state.items.firstIndex(where: { $0.id == id }) {
            state.items[index] = updatedItem
        }
    }

    // MARK: - Error Handling

    /// Clears any error state.
    func clearError() {
        state.error = nil
    }
}
```

### 4. Providers/myProvider.swift

```swift
import Riverpods

// MARK: - Main Provider

/// The main provider for MyFeature state.
///
/// Use this to access the current state and notifier:
/// ```swift
/// @Watch(myProvider) var state
/// let notifier = container.read(myProvider.notifier)
/// ```
let myProvider = NotifierProvider(cacheTime: 300.0) { MyNotifier() }

// MARK: - Derived Providers

/// Provides the list of items.
let itemsProvider = Provider { ref in
    let state = ref.watch(myProvider)
    return state.items
}

/// Provides the selected item, if any.
let selectedItemProvider = Provider { ref in
    let state = ref.watch(myProvider)
    return state.selectedItem
}

/// Provides whether the feature is currently loading.
let isLoadingProvider = Provider { ref in
    let state = ref.watch(myProvider)
    return state.isLoading
}

/// Provides the current error, if any.
let errorProvider = Provider { ref in
    let state = ref.watch(myProvider)
    return state.error
}

/// Provides the count of items.
let itemCountProvider = Provider { ref in
    let state = ref.watch(myProvider)
    return state.items.count
}
```

### 5. Views/MyView.swift

```swift
import SwiftUI
import Riverpods

/// The main view for MyFeature.
struct MyView: View {
    // MARK: - Properties

    @Watch(myProvider) var state
    @Watch(itemsProvider) var items
    @Environment(\.providerContainer) var container

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if state.isLoading {
                    loadingView
                } else if let error = state.error {
                    errorView(error)
                } else if items.isEmpty {
                    emptyView
                } else {
                    itemsListView
                }
            }
            .navigationTitle("My Feature")
            .toolbar {
                Button("Refresh") {
                    Task {
                        let notifier = container.read(myProvider.notifier)
                        await notifier.loadItems()
                    }
                }
            }
        }
        .onAppear {
            Task {
                let notifier = container.read(myProvider.notifier)
                await notifier.loadItems()
            }
        }
    }

    // MARK: - Views

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading...")
                .foregroundColor(.secondary)
        }
    }

    private func errorView(_ error: MyError) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text(error.description)
                .font(.headline)

            Button("Retry") {
                Task {
                    let notifier = container.read(myProvider.notifier)
                    await notifier.loadItems()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Items")
                .font(.headline)

            Text("Tap refresh to load items")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var itemsListView: some View {
        List {
            ForEach(items) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.headline)
                        Text(item.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let notifier = container.read(myProvider.notifier)
                        notifier.selectItem(item)
                    }
                }
            }
            .onDelete { indexSet in
                let notifier = container.read(myProvider.notifier)
                for index in indexSet {
                    notifier.removeItem(withId: items[index].id)
                }
            }
        }
    }
}

// MARK: - Detail View

struct ItemDetailView: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(item.name)
                .font(.title2)
                .fontWeight(.bold)

            Text(item.description)
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    MyView()
        .environment(\.providerContainer, ProviderContainer())
}
```

### 6. Composition/MyComposition.swift

```swift
import Foundation
import Riverpods

/// Composition utilities for MyFeature.
enum MyComposition {
    /// Builds the complete feature view with all dependencies set up.
    static func buildFeatureView() -> some View {
        MyView()
    }

    /// Overrides for testing.
    static func testOverrides() -> [ProviderOverride] {
        [
            myProvider.overrideWith(
                NotifierProvider { MyNotifier() }
            ),
        ]
    }
}
```

### 7. Public.swift

```swift
@_exported import Foundation

// MARK: - Public Types

public typealias MyState = MyModule.MyState
public typealias Item = MyModule.Item
public typealias MyError = MyModule.MyError

// MARK: - Public Providers

public let myProvider = MyModule.myProvider
public let itemsProvider = MyModule.itemsProvider
public let selectedItemProvider = MyModule.selectedItemProvider
public let isLoadingProvider = MyModule.isLoadingProvider
public let errorProvider = MyModule.errorProvider
public let itemCountProvider = MyModule.itemCountProvider

// MARK: - Public Views

public struct MyFeatureAPI {
    public static func view() -> some View {
        MyView()
    }
}
```

---

## Template 2: Async Feature (with Loading States)

Use this for features that perform async operations.

### State Definition

```swift
import Foundation

struct AsyncFeatureState: Sendable {
    enum AsyncState: Sendable {
        case idle
        case loading(previousData: Data?)
        case loaded(Data)
        case error(Error?, previousData: Data?)
        case refreshing(Data)
    }

    var asyncState: AsyncState = .idle
    var lastRefreshedAt: Date?

    var data: Data? {
        switch asyncState {
        case .loaded(let data), .refreshing(let data):
            return data
        case .error(_, let previous):
            return previous
        default:
            return nil
        }
    }

    var isLoading: Bool {
        if case .loading = asyncState { return true }
        return false
    }

    var error: Error? {
        if case .error(let error, _) = asyncState { return error }
        return nil
    }
}

struct Data: Sendable {
    let items: [String]
}
```

### Notifier Definition

```swift
@MainActor
@Observable
open class AsyncFeatureNotifier: Notifier<AsyncFeatureState> {
    override func build() -> AsyncFeatureState {
        AsyncFeatureState()
    }

    func load() async {
        state.asyncState = .loading(previousData: state.data)

        do {
            let data = try await fetchData()
            state.asyncState = .loaded(data)
            state.lastRefreshedAt = Date()
        } catch {
            state.asyncState = .error(error, previousData: state.data)
        }
    }

    func refresh() async {
        guard case .loaded(let data) = state.asyncState else { return }

        state.asyncState = .refreshing(data)

        do {
            let newData = try await fetchData()
            state.asyncState = .loaded(newData)
            state.lastRefreshedAt = Date()
        } catch {
            state.asyncState = .error(error, previousData: data)
        }
    }

    private func fetchData() async throws -> Data {
        try await Task.sleep(nanoseconds: 2_000_000_000)
        return Data(items: ["Item 1", "Item 2", "Item 3"])
    }
}
```

### View Definition

```swift
struct AsyncFeatureView: View {
    @Watch(asyncFeatureProvider) var state
    @Environment(\.providerContainer) var container

    @ViewBuilder
    var body: some View {
        switch state.asyncState {
        case .idle:
            VStack {
                Button("Load Data") {
                    Task {
                        let notifier = container.read(asyncFeatureProvider.notifier)
                        await notifier.load()
                    }
                }
            }

        case .loading(let previousData):
            if let data = previousData {
                loadedView(data)
                    .redacted(reason: .placeholder)
            } else {
                ProgressView("Loading...")
            }

        case .loaded(let data):
            loadedView(data)
                .toolbar {
                    Button("Refresh") {
                        Task {
                            let notifier = container.read(asyncFeatureProvider.notifier)
                            await notifier.refresh()
                        }
                    }
                }

        case .refreshing(let data):
            loadedView(data)
                .overlay(alignment: .top) {
                    ProgressView()
                        .padding()
                }

        case .error(let error, let previousData):
            VStack {
                if let data = previousData {
                    loadedView(data)
                        .opacity(0.5)
                }

                if let error = error {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                }

                Button("Retry") {
                    Task {
                        let notifier = container.read(asyncFeatureProvider.notifier)
                        await notifier.load()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func loadedView(_ data: Data) -> some View {
        List {
            ForEach(data.items, id: \.self) { item in
                Text(item)
            }
        }
    }
}
```

---

## Template 3: Composed Feature (Multiple Substates)

Use this for features that manage multiple related domains.

### State Definition

```swift
struct ComposedState: Sendable {
    var authState: AuthState = AuthState()
    var uiState: UIState = UIState()
    var dataState: DataState = DataState()

    struct AuthState: Sendable {
        var isAuthenticated = false
        var user: User?
    }

    struct UIState: Sendable {
        var isLoading = false
        var selectedTab = 0
    }

    struct DataState: Sendable {
        var items: [Item] = []
        var filter: String = ""
    }
}
```

### Notifier Definition

```swift
@MainActor
@Observable
open class ComposedNotifier: Notifier<ComposedState> {
    override func build() -> ComposedState {
        ComposedState()
    }

    // MARK: - Auth Operations

    func authenticate(_ user: User) {
        state.authState.user = user
        state.authState.isAuthenticated = true
    }

    func logout() {
        state.authState.user = nil
        state.authState.isAuthenticated = false
    }

    // MARK: - UI Operations

    func setLoading(_ isLoading: Bool) {
        state.uiState.isLoading = isLoading
    }

    func selectTab(_ index: Int) {
        state.uiState.selectedTab = index
    }

    // MARK: - Data Operations

    func loadItems() async {
        state.uiState.isLoading = true
        defer { state.uiState.isLoading = false }

        do {
            let items = try await fetchItems()
            state.dataState.items = items
        } catch {
            // Handle error
        }
    }

    func setFilter(_ filter: String) {
        state.dataState.filter = filter
    }

    // MARK: - Private

    private func fetchItems() async throws -> [Item] {
        // Fetch logic
        return []
    }
}
```

---

## Template 4: Feature with Dependencies

Use this when your feature depends on other modules.

### Notifier with Dependencies

```swift
@MainActor
@Observable
open class DependentNotifier: Notifier<FeatureState> {
    override func build() -> FeatureState {
        // Access dependencies via ref
        let networkClient = ref.watch(networkClientProvider)
        let userPreferences = ref.watch(userPreferencesProvider)
        let authState = ref.watch(authProvider)

        // Initialize state based on dependencies
        return FeatureState()
    }

    func performAction() async {
        // Get current dependency values
        let networkClient = ref.watch(networkClientProvider)

        do {
            let result = try await networkClient.fetch(...)
            // Handle result
        } catch {
            // Handle error
        }
    }
}
```

---

## Testing Template

### Unit Test

```swift
import XCTest
import StateKitTesting

final class MyNotifierTests: XCTestCase {
    var notifier: MyNotifier!

    override func setUp() {
        super.setUp()
        notifier = MyNotifier()
    }

    func testInitialState() {
        let state = notifier.state
        XCTAssertTrue(state.items.isEmpty)
        XCTAssertNil(state.selectedItem)
        XCTAssertFalse(state.isLoading)
    }

    func testAddItem() {
        let item = Item(id: 1, name: "Test", description: "Test item")
        notifier.addItem(item)

        XCTAssertEqual(notifier.state.items.count, 1)
        XCTAssertEqual(notifier.state.items.first?.name, "Test")
    }

    func testSelectItem() {
        let item = Item(id: 1, name: "Test", description: "Test item")
        notifier.addItem(item)
        notifier.selectItem(item)

        XCTAssertEqual(notifier.state.selectedItem?.id, 1)
    }
}
```

### Integration Test

```swift
import XCTest

final class MyFeatureIntegrationTests: XCTestCase {
    var container: ProviderContainer!

    override func setUp() {
        super.setUp()
        container = ProviderContainer()
    }

    func testFeatureFlow() async {
        let notifier = container.read(myProvider.notifier)

        // Test loading
        await notifier.loadItems()

        let state = container.read(myProvider)
        XCTAssertFalse(state.items.isEmpty)
    }
}
```

---

## Directory Structure Checklist

```
✅ MyFeature/
  ├── ✅ Models/
  │   ├── MyState.swift
  │   └── MyError.swift
  ├── ✅ Notifiers/
  │   └── MyNotifier.swift
  ├── ✅ Providers/
  │   └── myProvider.swift
  ├── ✅ Views/
  │   ├── MyView.swift
  │   └── MyDetailView.swift
  ├── ✅ Composition/
  │   └── MyComposition.swift
  ├── ✅ Tests/
  │   ├── MyNotifierTests.swift
  │   └── MyIntegrationTests.swift
  ├── ✅ Public.swift
  └── ✅ Package.swift (if standalone module)
```

---

## Common Patterns

### Pattern 1: Filtering Items

```swift
let filteredItemsProvider = Provider { ref in
    let state = ref.watch(myProvider)
    let filter = ref.watch(filterProvider)

    return state.items.filter { item in
        item.name.localizedCaseInsensitiveContains(filter)
    }
}
```

### Pattern 2: Pagination

```swift
struct PaginationState: Sendable {
    var page = 1
    var pageSize = 20
}

func loadNextPage() async {
    let currentPage = state.pagination.page
    let items = try await fetchItems(page: currentPage, pageSize: state.pagination.pageSize)
    state.items.append(contentsOf: items)
    state.pagination.page += 1
}
```

### Pattern 3: Search with Debounce

```swift
func search(_ query: String) async {
    state.searchQuery = query

    // Debounce implementation
    try await Task.sleep(nanoseconds: 500_000_000)  // 0.5s delay

    let results = try await performSearch(query: query)
    state.searchResults = results
}
```

---

## Migration Checklist

When moving a feature to modular architecture:

- [ ] Create Models folder with state and error types
- [ ] Create Notifiers folder with main notifier
- [ ] Create Providers folder with all providers
- [ ] Move Views to Views folder
- [ ] Create Composition folder with composition helpers
- [ ] Create Tests folder with unit and integration tests
- [ ] Create Public.swift with controlled exports
- [ ] Update imports in existing code
- [ ] Run all tests
- [ ] Update documentation

---

**Templates Version**: 2.0.0  
**Last Updated**: May 17, 2026  
**See Also**: [MODULARITY_GUIDE.md](MODULARITY_GUIDE.md) for detailed guidance
