# Advanced Integrations Guide - Phase 6 (v2.5)

**Version**: 2.5.0-beta  
**Date**: May 17, 2026  
**Status**: Complete

---

## Overview

Phase 6 provides advanced integration patterns for StateKit with:

- **SwiftData Integration** - Sync StateKit state with SwiftData @Model objects
- **CloudKit Integration** - Real-time cloud synchronization with conflict resolution
- **Keychain Integration** - Secure storage for sensitive data
- **visionOS Support** - Spatial computing with 3D state management
- **UserDefaults Persistence** - Lightweight persistent atoms
- **Migration Helpers** - Version management and data migration

**Total Deliverables:**
- StateKitPersistence module (400+ lines)
- 3 complete integration examples (900+ lines)
- 40+ page comprehensive guide
- Production-ready persistence patterns

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [SwiftData Integration](#swiftdata-integration)
3. [Keychain Integration](#keychain-integration)
4. [UserDefaults Persistence](#userdefaults-persistence)
5. [CloudKit Integration](#cloudkit-integration)
6. [visionOS Spatial Computing](#visionos-spatial-computing)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

---

## Quick Start

### SwiftData Sync (5 minutes)

```swift
// Define your model
@Model
final class Todo {
    @Attribute(.unique) var id: String
    var title: String
    var isCompleted: Bool
}

// Create notifier
let todoNotifier = NotifierProvider { ref -> TodoNotifier in
    TodoNotifier(ref: ref, context: modelContext)
}

// Sync to StateKit atoms
final class TodoNotifier: Notifier {
    func addTodo(title: String) {
        let item = TodoItemDTO(id: UUID().uuidString, title: title)
        var items = ref.read(todoItemsAtom)
        items.append(item)
        ref.read(todoItemsAtom.notifier).state = items
        
        syncToSwiftData(item)  // Also save to database
    }
}
```

### Keychain Storage (5 minutes)

```swift
// Define secure data
let authTokenProvider = KeychainStateProvider<AuthToken>(
    key: "authToken",
    accessibility: .whenUnlocked
)

// Retrieve
let token = try authTokenProvider.retrieve()

// Store
try authTokenProvider.store(AuthToken(accessToken: "token123"))

// Delete
try authTokenProvider.delete()
```

### UserDefaults Persistence (5 minutes)

```swift
// Define serializable type
struct AppPreferences: UserDefaultsSerializable {
    let isDarkMode: Bool
    let fontSize: Int
    
    static let userDefaultsKey = "appPreferences"
    static let defaultValue = AppPreferences(isDarkMode: false, fontSize: 16)
}

// Create atom from UserDefaults
let preferencesAtom = userDefaultsAtom(AppPreferences.self)

// Auto-persists on changes
@Watch(var prefs: preferencesAtom) var prefs
```

---

## SwiftData Integration

### Overview

SwiftData provides type-safe database persistence. StateKit integrates seamlessly:

- **Bidirectional Sync**: Changes in StateKit → SwiftData, and vice versa
- **Query Providers**: Fetch data as reactive providers
- **Conflict Resolution**: Handle concurrent updates gracefully
- **Background Sync**: Async synchronization without blocking UI

### Basic Setup

```swift
// Import
import SwiftData
import StateKitPersistence

// Create storage
@Model
final class Task {
    @Attribute(.unique) var id: String
    var title: String
    var description: String
    var isCompleted: Bool
    var createdAt: Date
}

// Create atom for task state
@SKStateAtom
var tasksAtom: [TaskDTO] = []

// Create notifier for business logic
let taskNotifier = NotifierProvider { ref -> TaskNotifier in
    TaskNotifier(ref: ref, modelContext: modelContext)
}

final class TaskNotifier: Notifier, Sendable {
    let ref: NotifierProviderRef
    let modelContext: ModelContext
    
    init(ref: NotifierProviderRef, modelContext: ModelContext) {
        self.ref = ref
        self.modelContext = modelContext
    }
    
    func addTask(title: String) {
        // Create local atom state
        let dto = TaskDTO(id: UUID().uuidString, title: title)
        var tasks = ref.read(tasksAtom)
        tasks.append(dto)
        ref.read(tasksAtom.notifier).state = tasks
        
        // Also persist to SwiftData
        let model = Task(id: dto.id, title: title, ...)
        modelContext.insert(model)
        try? modelContext.save()
    }
}
```

### Query Providers

Fetch SwiftData models as reactive providers:

```swift
// Query all tasks
let tasksQueryProvider = FutureProvider { ref in
    let descriptor = FetchDescriptor<Task>()
    return try modelContext.fetch(descriptor)
}

// Query with predicate
let completedTasksProvider = FutureProvider { ref in
    var descriptor = FetchDescriptor<Task>()
    descriptor.predicate = #Predicate { $0.isCompleted }
    return try modelContext.fetch(descriptor)
}

// Query with family (parameterized)
let taskByIdProvider = FutureProvider.family { (ref, id: String) in
    var descriptor = FetchDescriptor<Task>()
    descriptor.predicate = #Predicate { $0.id == id }
    let results = try modelContext.fetch(descriptor)
    return results.first
}

// Use in view
@Watch(task: taskByIdProvider("task123")) var task
```

### Sync Strategies

**Strategy 1: Event-Based Sync**

```swift
// Sync when atom changes
final class EventSyncNotifier: Notifier {
    func onTaskChanged(_ task: TaskDTO) {
        // Update SwiftData immediately
        updateSwiftDataModel(task)
    }
}
```

**Strategy 2: Debounced Sync**

```swift
// Sync after delay to batch updates
final class DebouncedSyncNotifier: Notifier {
    private var syncTask: Task<Void, Never>?
    
    func updateTask(_ task: TaskDTO) {
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
            updateSwiftData(task)
        }
    }
}
```

**Strategy 3: Explicit Sync**

```swift
// User-initiated sync
final class ExplicitSyncNotifier: Notifier {
    func syncNow() async {
        let atoms = ref.read(tasksAtom)
        for task in atoms {
            try? updateSwiftData(task)
        }
    }
}
```

### Handling Conflicts

When SwiftData and StateKit diverge:

```swift
struct ConflictResolution {
    /// Prefer local state
    static func preferLocal<T>(_ local: T, _ remote: T) -> T {
        return local
    }
    
    /// Prefer remote (database of record)
    static func preferRemote<T>(_ local: T, _ remote: T) -> T {
        return remote
    }
    
    /// Merge intelligently
    static func mergeTimestamp(
        local: TimestampedValue,
        remote: TimestampedValue
    ) -> TimestampedValue {
        return local.timestamp > remote.timestamp ? local : remote
    }
}
```

---

## Keychain Integration

### Overview

Keychain provides iOS/macOS/watchOS secure storage for:

- Authentication tokens
- Passwords and credentials
- API keys
- Biometric data
- Cryptographic keys

### Basic Usage

```swift
// Create provider
let authTokenProvider = KeychainStateProvider<AuthToken>(
    key: "authToken",
    accessibility: .whenUnlocked  // When device unlocked
)

// Retrieve
if let token = try authTokenProvider.retrieve() {
    print("Token: \(token.accessToken)")
}

// Store
let token = AuthToken(accessToken: "abc123", refreshToken: "def456")
try authTokenProvider.store(token)

// Delete
try authTokenProvider.delete()

// Check existence
if authTokenProvider.exists() {
    print("Token stored in Keychain")
}
```

### Accessibility Levels

| Level | Use Case | Security |
|-------|----------|----------|
| `whenUnlocked` | Common data | Medium (device must be unlocked) |
| `afterFirstUnlock` | Sensitive data | High (available after first unlock) |
| `always` | Always accessible | Low (risky) |
| `whenUnlockedThisDeviceOnly` | Private data | Highest (this device only) |

```swift
// Biometric data (high security)
let biometricProvider = KeychainStateProvider<BiometricState>(
    key: "biometric",
    accessibility: .afterFirstUnlockThisDeviceOnly
)

// Session token (medium security)
let sessionProvider = KeychainStateProvider<String>(
    key: "sessionToken",
    accessibility: .whenUnlocked
)
```

### NotifierProvider Integration

```swift
// Create notifier for auth management
let authNotifier = KeychainNotifierProvider.create(
    key: "authToken",
    initial: AuthToken(accessToken: ""),
    accessibility: .whenUnlocked
)

// Use in view
final class AuthNotifier: Notifier {
    func saveAuthToken(_ token: AuthToken) throws {
        let notifier = container.read(authNotifier)
        try notifier.update(token)
    }
    
    func clearAuth() throws {
        let notifier = container.read(authNotifier)
        try notifier.clear()
    }
}
```

### Batch Operations

```swift
var batch = KeychainBatch()
try batch.add(authToken, forKey: "authToken")
try batch.add(credentials, forKey: "credentials")
try batch.add(refreshToken, forKey: "refreshToken")

// Store all at once
try batch.store(accessibility: .whenUnlocked)

// Delete all
try batch.deleteAll()
```

### Migration and Rotation

```swift
// Migrate token from old key to new key
try KeychainMigration.migrateKey(
    from: "oldAuthToken",
    to: "newAuthToken",
    type: AuthToken.self
)

// Rotate token (e.g., after API refresh)
let newToken = AuthToken(accessToken: "newToken")
try KeychainMigration.rotate(
    key: "authToken",
    with: newToken,
    type: AuthToken.self
)
```

### Error Handling

```swift
do {
    try authTokenProvider.store(token)
} catch KeychainError.storeFailed(let status) {
    print("Failed to store: status \(status)")
} catch KeychainError.retrievalFailed(let status) {
    print("Failed to retrieve: status \(status)")
} catch KeychainError.deleteFailed(let status) {
    print("Failed to delete: status \(status)")
}
```

---

## UserDefaults Persistence

### Overview

UserDefaults provides lightweight persistence for app settings:

- User preferences
- App state
- Non-sensitive data
- Quick access values

### Basic Usage

```swift
// Define serializable type
struct AppPreferences: UserDefaultsSerializable {
    let isDarkMode: Bool
    let language: String
    let fontSize: Int
    
    static let userDefaultsKey = "appPreferences"
    static let defaultValue = AppPreferences(
        isDarkMode: false,
        language: "en",
        fontSize: 16
    )
}

// Create atom
let preferencesAtom = userDefaultsAtom(AppPreferences.self)

// Use in view
@Watch(var prefs: preferencesAtom) var prefs

// Changes auto-persist
prefs.isDarkMode = true  // Automatically saved
```

### Storage Management

```swift
let storage = PersistentAtomStorage<AppPreferences>(
    type: AppPreferences.self,
    suiteName: nil  // Use standard defaults
)

// Load current value
let current = storage.load()

// Save new value
let updated = AppPreferences(isDarkMode: true, language: "en", fontSize: 16)
storage.save(updated)

// Delete
storage.delete()

// Export as JSON
if let json = storage.exportAsJSON() {
    // Share or backup
}

// Import from JSON
let imported = storage.importFromJSON(jsonData)
```

### Common Types

StateKit provides pre-built types:

```swift
// App preferences
let prefs = AppPreferences(
    isDarkMode: false,
    language: "en",
    lastOpenedDate: Date()
)

// Cache metadata
let metadata = CacheMetadata(
    lastUpdated: Date(),
    version: 1,
    itemCount: 42
)

// Session info
let session = SessionInfo(
    userId: "user123",
    sessionToken: "token",
    loginTime: Date()
)
```

### Observation

```swift
let storage = PersistentAtomStorage<AppPreferences>(
    type: AppPreferences.self
)

// Add observer
storage.addObserver { newValue in
    print("Preferences changed: \(newValue)")
}

// Save (triggers observers)
storage.save(updatedPreferences)
```

### Migration

```swift
// Version 1 → Version 2 migration
let migration = PersistenceMigration<AppPreferences>(
    storage: storage,
    version: 2
)

if migration.needsMigration(fromVersion: 1) {
    migration.migrate(from: 1) { prefs in
        // Update to new format
        // prefs.fontSize = max(prefs.fontSize, 12)
    }
}
```

---

## CloudKit Integration

### Overview

CloudKit enables cloud synchronization with:

- Automatic iCloud sync
- Conflict resolution
- Offline-first architecture
- Real-time updates

### Setup

```swift
// Define CloudKit model
@Model
final class CloudNote {
    @Attribute(.unique) var id: String
    var title: String
    var content: String
    var modifiedAt: Date
}

// Define atom for local state
@SKStateAtom
var notesAtom: [CloudNote] = []

@SKStateAtom
var syncStateAtom: SyncState = .idle
```

### Sync Patterns

**Pattern 1: Pull on App Start**

```swift
final class CloudSyncNotifier: Notifier {
    func loadFromCloud() async {
        updateState(.syncing)
        
        do {
            let cloudNotes = try await fetchFromCloudKit()
            ref.read(notesAtom.notifier).state = cloudNotes
            updateState(.synced)
        } catch {
            updateState(.error(error.localizedDescription))
        }
    }
}
```

**Pattern 2: Push on Update**

```swift
func updateNote(_ note: CloudNote) {
    // Update local
    updateLocalNote(note)
    
    // Push to CloudKit
    Task {
        try await pushToCloudKit(note)
    }
}
```

**Pattern 3: Bidirectional Sync**

```swift
func syncBidirectional() async {
    // 1. Push local changes
    let unsyncedLocal = getLocalChanges()
    try await pushToCloudKit(unsyncedLocal)
    
    // 2. Pull remote changes
    let cloudChanges = try await fetchFromCloudKit(since: lastSyncTime)
    mergeCloudChanges(cloudChanges)
    
    // 3. Resolve conflicts
    let conflicts = findConflicts(local: getLocal(), remote: cloudChanges)
    resolveConflicts(conflicts)
}
```

### Conflict Resolution

```swift
enum ConflictStrategy {
    case preferLocal    // Keep local version
    case preferRemote   // Use cloud version
    case merge((local: CloudNote, remote: CloudNote) -> CloudNote)
}

let resolver = ConflictResolver()

let resolved = resolver.resolve(
    local: localNote,
    remote: cloudNote,
    strategy: .merge { local, remote in
        // Custom merge logic
        if remote.modifiedAt > local.modifiedAt {
            return remote  // Cloud is newer
        }
        return local  // Local is newer
    }
)
```

### Offline Support

```swift
final class OfflineCloudNotifier: Notifier {
    func createNote(_ note: CloudNote) {
        // 1. Create local immediately
        addLocalNote(note)
        
        // 2. Mark for sync
        addToSyncQueue(note)
        
        // 3. Try to sync (non-blocking)
        Task {
            try? await pushToCloudKit(note)
        }
    }
}
```

---

## visionOS Spatial Computing

### Overview

visionOS brings 3D spatial computing to StateKit:

- 3D object management
- Hand gesture tracking
- Spatial UI composition
- Multi-window coordination

### State Management for 3D

```swift
// Define 3D object
struct SpatialObject: Sendable {
    let id: String
    var position: SIMD3<Float>      // X, Y, Z
    var rotation: simd_quatf         // 3D rotation
    var scale: Float                 // Size
    var isSelected: Bool
}

// Atoms for 3D state
@SKStateAtom
var objectsAtom: [SpatialObject] = []

@SKStateAtom
var selectedObjectIdAtom: String?

// Providers
let selectedObjectProvider = Provider { ref in
    let selectedId = ref.watch(selectedObjectIdAtom)
    let objects = ref.watch(objectsAtom)
    return objects.first { $0.id == selectedId }
}
```

### Gesture Handling

```swift
struct GestureInput: Sendable {
    let type: GestureType
    let position: SIMD3<Float>
    let velocity: SIMD3<Float>?
    
    enum GestureType: String, Sendable {
        case tap
        case pinch
        case drag
        case rotate
    }
}

// Record gestures
final class SpatialNotifier: Notifier {
    func handleTap(at position: SIMD3<Float>) {
        recordGesture(.tap, position: position)
        selectObject(at: position)
    }
    
    func handlePinch(_ scale: Float) {
        recordGesture(.pinch)
        scaleSelectedObject(by: scale)
    }
    
    func handleDrag(offset: SIMD3<Float>) {
        recordGesture(.drag, velocity: offset)
        moveSelectedObject(by: offset)
    }
}
```

### 3D Transformations

```swift
// Move object
extension SpatialObject {
    mutating func move(by offset: SIMD3<Float>) {
        position += offset
    }
    
    // Rotate object
    mutating func rotate(by quaternion: simd_quatf) {
        rotation = quaternion * rotation
    }
    
    // Scale object
    mutating func scale(by factor: Float) {
        scale = max(0.1, min(10.0, scale * factor))
    }
}
```

### Multi-Object Editing

```swift
// Select multiple objects
let selectedObjectsProvider = Provider { ref in
    let objects = ref.watch(objectsAtom)
    return objects.filter { $0.isSelected }
}

// Transform all selected objects
final class BatchTransformNotifier: Notifier {
    func moveAllSelected(by offset: SIMD3<Float>) {
        var objects = ref.read(objectsAtom)
        for i in 0..<objects.count {
            if objects[i].isSelected {
                objects[i].move(by: offset)
            }
        }
        ref.read(objectsAtom.notifier).state = objects
    }
}
```

---

## Best Practices

### 1. Choose the Right Persistence

| Data | Tool | Why |
|------|------|-----|
| User preferences | UserDefaults | Lightweight, quick |
| App data | SwiftData | Type-safe, queryable |
| Auth tokens | Keychain | Secure, encrypted |
| Cloud sync | CloudKit | Automatic iCloud sync |

### 2. Handle Sync Errors Gracefully

```swift
// ✅ Good: explicit error handling
@SKStateAtom
var syncErrorAtom: String?

final class SyncNotifier: Notifier {
    func sync() async {
        do {
            try await syncWithServer()
        } catch {
            ref.read(syncErrorAtom.notifier).state = error.localizedDescription
            // User sees error
        }
    }
}

// ❌ Avoid: silent failures
final class BadNotifier: Notifier {
    func sync() {
        try? syncWithServer()  // Silently fails
    }
}
```

### 3. Avoid Sync Conflicts

```swift
// ✅ Good: single source of truth
@SKStateAtom
var canonicalState: AppState = .initial

// All changes go through one notifier
let stateNotifier = NotifierProvider { ref -> StateNotifier in
    StateNotifier(ref: ref)
}

// ❌ Avoid: multiple conflicting sources
@SKStateAtom
var stateA: AppState = .initial

@SKStateAtom
var stateB: AppState = .initial  // Can diverge!
```

### 4. Batch Persistence Operations

```swift
// ✅ Good: batch save
var batch = KeychainBatch()
try batch.add(token1, forKey: "token1")
try batch.add(token2, forKey: "token2")
try batch.store()  // One operation

// ❌ Avoid: individual saves
try keychain1.store(token1)
try keychain2.store(token2)  // Multiple operations
```

### 5. Plan for Offline

```swift
// ✅ Good: offline queue
@SKStateAtom
var pendingSyncAtom: [Action] = []

final class OfflineNotifier: Notifier {
    func action(_ act: Action) {
        // 1. Apply locally
        applyLocally(act)
        
        // 2. Queue for sync
        queueForSync(act)
        
        // 3. Try sync (non-blocking)
        Task {
            do {
                try await sync()
            } catch {
                // Already queued, will retry
            }
        }
    }
}
```

---

## Troubleshooting

### SwiftData Issues

**Problem**: Data not persisting to SwiftData

```swift
// ❌ Forget to call save()
modelContext.insert(model)
// Data not saved!

// ✅ Always save changes
modelContext.insert(model)
try modelContext.save()
```

**Problem**: Atom and SwiftData out of sync

```swift
// ✅ Good: sync immediately
final class SyncNotifier: Notifier {
    func update(_ item: Item) {
        // 1. Update atom
        updateAtom(item)
        
        // 2. Sync to SwiftData immediately
        try? syncToSwiftData(item)
    }
}
```

### Keychain Issues

**Problem**: "Keychain item not found"

```swift
// Check before retrieve
if authProvider.exists() {
    let token = try authProvider.retrieve()
}
```

**Problem**: Accessibility restrictions

```swift
// Wrong accessibility for use case
let provider = KeychainStateProvider<String>(
    key: "sessionToken",
    accessibility: .always  // Too permissive!
)

// Use appropriate level
let provider = KeychainStateProvider<String>(
    key: "sessionToken",
    accessibility: .whenUnlocked  // Better
)
```

### CloudKit Issues

**Problem**: "Network timeout"

```swift
// ✅ Good: handle timeouts
func syncWithRetry() async {
    for attempt in 0..<3 {
        do {
            try await sync()
            return
        } catch {
            guard attempt < 2 else { throw error }
            try await Task.sleep(nanoseconds: 1_000_000_000 * (1 << attempt))
        }
    }
}
```

**Problem**: Merge conflicts not resolved

```swift
// ❌ Avoid: ignoring conflicts
let remote = fetchFromCloud()
ref.read(notesAtom.notifier).state = remote  // Loses local data!

// ✅ Good: merge intelligently
let local = ref.read(notesAtom)
let merged = mergeNotes(local, remote)
ref.read(notesAtom.notifier).state = merged
```

---

## Migration Checklist

When adding persistence to existing apps:

- ✅ Choose persistence strategy (UserDefaults vs SwiftData vs Keychain)
- ✅ Define data models with Codable conformance
- ✅ Create atoms for persisted state
- ✅ Create notifiers for sync logic
- ✅ Handle errors explicitly
- ✅ Test offline scenarios
- ✅ Plan for data migrations
- ✅ Document sync strategy

---

## References

- [StateKit Documentation](README.md)
- [Real-World Guide](REAL_WORLD_GUIDE.md)
- [Testing Excellence Guide](TESTING_EXCELLENCE_GUIDE.md)
- [Architecture Guide](ARCHITECTURE_GUIDE.md)

---

**Version**: 2.5.0-beta  
**Status**: Complete  
**Last Updated**: May 17, 2026  
**Next**: Extended Features (Phase 7+)
