# DevTools UI Guide

**Version**: 2.2.0  
**Date**: May 17, 2026  
**Status**: Phase 3b Complete

---

## Overview

StateKit DevTools now includes a complete **visual debugging interface** with tabs for history navigation, performance metrics, state inspection, and configuration.

**Key Components**:
- **StateDevTools** - Full-featured debugging overlay
- **DevToolsHandle** - Floating action button with badge
- **DevToolsMiniPanel** - Compact panel for limited space
- **DevToolsQuickStats** - Summary statistics view

---

## Quick Start

### 1. Setup (2 lines)

```swift
import StateKitDevTools

let devTools = DevToolsObserver()
let container = ProviderContainer(observers: [devTools])
```

### 2. Add to UI

```swift
ZStack {
    MyAppView()
        .environment(\.providerContainer, container)

    @State var showDevTools = false

    VStack {
        Spacer()
        HStack {
            Spacer()
            DevToolsHandle(showDevTools: $showDevTools, observer: devTools)
        }
    }

    if showDevTools {
        StateDevTools(observer: devTools)
            .ignoresSafeArea()
    }
}
```

### 3. Done! ✅

All state changes are now tracked and visible in the overlay.

---

## Components

### StateDevTools (Main Overlay)

The comprehensive debugging overlay with full feature set.

**Usage**:
```swift
@State private var showDevTools = false

StateDevTools(observer: devTools)
    .ignoresSafeArea()
```

**Tabs**:

#### 1. History Tab
- Browse all recorded state changes
- Search by action name
- See timestamp and compute time
- Navigate with back/forward buttons
- Jump to specific points
- Clear history

**Features**:
- Chronological list of state changes
- Filter by action name
- Compute time for each change
- Current position indicator
- Time-travel controls

#### 2. Metrics Tab
- Real-time performance metrics
- Slowest providers (sorted)
- Most frequently updated providers
- Compute time visualization
- Update frequency display
- Call count tracking
- Performance scoring

**Sorting Options**:
- By compute time (slowest first)
- By update frequency (most frequent)
- By call count (most called)

#### 3. Inspector Tab
- View current state value
- See state at any history point
- Copy state as JSON
- Export all data

**Features**:
- Syntax-highlighted state display
- History position indicator
- One-click export to clipboard
- Full JSON export support

#### 4. Settings Tab
- Configure max history size
- Enable debug logging
- Adjust refresh rates
- Memory management

**Options**:
- Max history entries (10-500)
- Store snapshots toggle
- Debug logging toggle
- Performance recording options

---

## UI Components

### DevToolsHandle (Floating Button)

Toggles the DevTools overlay on/off.

**Basic Usage**:
```swift
@State var showDevTools = false

DevToolsHandle(showDevTools: $showDevTools)
```

**With Observer**:
```swift
DevToolsHandle(
    showDevTools: $showDevTools,
    observer: devTools
)
```

**Customization**:
```swift
DevToolsHandle(
    showDevTools: $showDevTools,
    observer: devTools,
    size: 70,
    backgroundColor: .blue,
    foregroundColor: .white
)
```

**Features**:
- Shows state change count badge
- Smooth animations
- Customizable size and colors
- Click to toggle overlay

### DevToolsMiniPanel (Compact Panel)

Compact alternative for screens with limited space.

**Usage**:
```swift
DevToolsMiniPanel(observer: devTools)
    .frame(height: 100)
    .padding()
```

**Shows**:
- State change count
- Current history position
- Slowest provider
- Navigation buttons
- Clear history button

**Best For**:
- Small screens
- Testing on iPhone
- Background monitoring
- Status display

### DevToolsQuickStats (Summary View)

Quick statistics display for overview.

**Usage**:
```swift
VStack {
    DevToolsQuickStats(observer: devTools)
    Spacer()
}
```

**Displays**:
- History entry count
- Average compute time
- Total provider updates
- Color-coded performance status

**Best For**:
- Dashboard displays
- Performance at a glance
- Integration with other UI
- Quick sanity checks

---

## Integration Patterns

### Pattern 1: Full Overlay (Recommended)

```swift
struct ContentView: View {
    @State private var showDevTools = false
    private let devTools = DevToolsObserver()

    var body: some View {
        ZStack {
            MyAppView()
                .environment(
                    \.providerContainer,
                    ProviderContainer(observers: [devTools])
                )

            if showDevTools {
                StateDevTools(observer: devTools)
                    .ignoresSafeArea()
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    DevToolsHandle(
                        showDevTools: $showDevTools,
                        observer: devTools
                    )
                }
            }
            .ignoresSafeArea()
        }
    }
}
```

### Pattern 2: Mini Panel in Settings

```swift
struct DebugSettingsView: View {
    let devTools: DevToolsObserver

    var body: some View {
        VStack {
            Text("Debug Panel")
                .font(.title)

            DevToolsMiniPanel(observer: devTools)

            Spacer()
        }
        .padding()
    }
}
```

### Pattern 3: Status Bar

```swift
struct MyApp: App {
    private let devTools = DevToolsObserver()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(
                    \.providerContainer,
                    ProviderContainer(observers: [devTools])
                )
                .safeAreaInset(edge: .bottom) {
                    #if DEBUG
                    DevToolsQuickStats(observer: devTools)
                    #endif
                }
        }
    }
}
```

### Pattern 4: Conditional Compilation

```swift
#if DEBUG
let observers: [ProviderObserver] = [DevToolsObserver()]
#else
let observers: [ProviderObserver] = []
#endif

let container = ProviderContainer(observers: observers)
```

---

## Best Practices

### 1. Use in DEBUG Only

```swift
#if DEBUG
let devTools = DevToolsObserver()
#else
let devTools: DevToolsObserver? = nil
#endif
```

### 2. Name Your Providers

```swift
// Good - searchable in UI
let userProvider = Provider(name: "user") { ... }

// Avoid - not helpful
let p1 = Provider { ... }
```

### 3. Monitor Performance

```swift
// Watch for slow providers
if let slowest = devTools.metrics.slowestProviders.first {
    if slowest.isSlowProvider {
        print("⚠️ \(slowest.providerName) is slow")
    }
}
```

### 4. Export Before Debugging

```swift
// Save state for later analysis
let json = devTools.exportAsJSON()
try json.write(
    toFile: "/tmp/debug.json",
    atomically: true,
    encoding: .utf8
)
```

### 5. Configure Limits

```swift
var devTools = DevToolsObserver()
devTools.maxHistoryEntries = 50  // Reduce memory
devTools.storeSnapshots = true    // Full snapshots
```

---

## Keyboard Shortcuts (Future)

Planned keyboard shortcuts:
- `Cmd + D` - Toggle DevTools (iOS Simulator)
- `Cmd + Z` - Undo (go back)
- `Cmd + Shift + Z` - Redo (go forward)
- `Cmd + C` - Copy current state
- `Cmd + E` - Export

---

## Performance Tips

### Memory Usage

```swift
// Reduce for long sessions
devTools.maxHistoryEntries = 25

// Reduce metrics records
devTools.maxMetricsRecords = 250

// Disable snapshots for memory efficiency
devTools.storeSnapshots = false
```

### CPU Usage

```swift
// Disable debug logging for performance
devTools.debugLoggingEnabled = false

// Clear history periodically
if devTools.history.entries.count > 50 {
    devTools.clearHistory()
}
```

---

## Troubleshooting

### DevTools Not Showing State Changes

**Problem**: History entries not appearing

**Solutions**:
1. Ensure observer is in ProviderContainer
2. Check that providers have names
3. Verify observer is not nil

```swift
// Correct setup
let devTools = DevToolsObserver()
let container = ProviderContainer(observers: [devTools])

// Check it's working
print(devTools.history.entries.count)
```

### High Memory Usage

**Problem**: App using too much memory

**Solutions**:
1. Reduce history entries
2. Disable snapshots
3. Reduce metrics records

```swift
var devTools = DevToolsObserver()
devTools.maxHistoryEntries = 25
devTools.storeSnapshots = false
```

### Overlay Not Dismissing

**Problem**: DevTools overlay won't close

**Solution**: Check state binding

```swift
// Correct
@State var showDevTools = false

// Use binding
DevToolsHandle(showDevTools: $showDevTools)
```

### No Metrics Showing

**Problem**: Performance metrics empty

**Solutions**:
1. Ensure providers are named
2. Give app time to record data
3. Check provider count

```swift
let count = devTools.metrics.allMetrics.count
print("Tracked providers: \(count)")
```

---

## UI Customization

### Custom Colors

```swift
DevToolsHandle(
    showDevTools: $showDevTools,
    backgroundColor: .purple,
    foregroundColor: .yellow
)
```

### Custom Size

```swift
DevToolsHandle(
    showDevTools: $showDevTools,
    size: 80  // Larger button
)
```

### Custom Placement

```swift
VStack {
    HStack {
        Spacer()
        DevToolsHandle(
            showDevTools: $showDevTools,
            observer: devTools
        )
    }
    .padding()

    Spacer()
}
```

---

## Real-World Examples

### Example 1: Shopping App

```swift
struct ShoppingApp: View {
    @State private var showDevTools = false
    private let devTools = DevToolsObserver()

    var body: some View {
        ZStack {
            ShoppingView()
                .environment(
                    \.providerContainer,
                    ProviderContainer(observers: [devTools])
                )

            if showDevTools {
                StateDevTools(observer: devTools)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    DevToolsHandle(
                        showDevTools: $showDevTools,
                        observer: devTools
                    )
                }
            }
            .ignoresSafeArea()
        }
    }
}
```

### Example 2: Authentication Flow

```swift
struct AuthView: View {
    let devTools: DevToolsObserver

    var body: some View {
        ZStack {
            if isAuthenticated {
                MainAppView()
            } else {
                LoginView()
            }

            #if DEBUG
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    DevToolsMiniPanel(observer: devTools)
                }
            }
            #endif
        }
    }
}
```

---

## What's Next

**Planned Enhancements** (v2.3+):
- [ ] Dependency graph visualization
- [ ] Redux DevTools integration
- [ ] Remote debugging support
- [ ] Advanced search and filtering
- [ ] Custom breakpoints
- [ ] State mutation replay
- [ ] Performance trending

---

## API Reference

### StateDevTools

```swift
public struct StateDevTools: View {
    public init(observer: DevToolsObserver)
}
```

### DevToolsHandle

```swift
public struct DevToolsHandle: View {
    public init(
        showDevTools: Binding<Bool>,
        observer: DevToolsObserver? = nil,
        size: CGFloat = 60,
        backgroundColor: Color = .blue,
        foregroundColor: Color = .white
    )
}
```

### DevToolsMiniPanel

```swift
public struct DevToolsMiniPanel: View {
    public init(observer: DevToolsObserver)
}
```

### DevToolsQuickStats

```swift
public struct DevToolsQuickStats: View {
    public init(observer: DevToolsObserver)
}
```

---

## Related Documents

- [DEVTOOLS_GUIDE.md](DEVTOOLS_GUIDE.md) - API reference
- [DEVTOOLS_INTEGRATION.md](DEVTOOLS_INTEGRATION.md) - Integration patterns
- [PHASE3A_COMPLETION.md](PHASE3A_COMPLETION.md) - Foundation summary
- [STATUS_REPORT.md](STATUS_REPORT.md) - Library status

---

**Version**: 2.2.0  
**Status**: Complete  
**Last Updated**: May 17, 2026  
**Next Phase**: v2.3 (Testing Excellence)
