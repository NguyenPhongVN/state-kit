# StateKit v2.0 - API Stability Guide

**Release Date**: May 2026  
**Version**: 2.0.0  
**Stability Level**: Production Ready

---

## 📋 API Stability Levels

StateKit APIs are marked with stability levels to indicate their maturity and likelihood of change:

| Level | Symbol | Meaning | When to Use |
|-------|--------|---------|------------|
| **Stable** | ✅ | API locked, safe for production | All production apps |
| **Beta** | ⚠️ | Likely stable, may have minor changes | New features, gather feedback |
| **Experimental** | 🚀 | Active development, expect changes | Internal use, early adopters |
| **Deprecated** | ⚠️ | Being phased out, migration path provided | Plan migration, use alternatives |

---

## ✅ STABLE APIs (Production Ready)

### StateKitCore
- `StateContext` - Scope for hook execution
- `StateRuntime` - Hook runtime system
- `StateSignal` - Reactive signal
- `StateRef` - Reference to scope

### StateKit (Hooks)
- ✅ `useState` - Local mutable state
- ✅ `useReducer` - Complex state management
- ✅ `useMemo` - Value memoization
- ✅ `useCallback` - Function memoization
- ✅ `useEffect` - Side effects with cleanup
- ✅ `useContext` - Access scope context
- ✅ `useAsyncTask` - Async operation tracking
- ✅ `AsyncPhase` enum - State machine for async

### Riverpods
- ✅ `Provider<T>` - Read-only computed value
- ✅ `StateProvider<T>` - Mutable state
- ✅ `FutureProvider<T>` - One-shot async
- ✅ `StreamProvider<T>` - Continuous stream
- ✅ `Notifier<T>` - Class-based state
- ✅ `AsyncNotifier<T>` - Async class-based state
- ✅ `AsyncSequenceProvider<T>` - AsyncSequence iteration
- ✅ `ProviderContainer` - State management hub
- ✅ `@Watch` - Reactive property wrapper
- ✅ `@Read` - Non-reactive read
- ✅ `ProviderScope` - Dependency injection
- ✅ `.select()` - Selector providers with keypath
- ✅ `.family()` - Parameterized providers
- ✅ `overrideWith()` - Provider override
- ✅ `ProviderObserver` - Lifecycle events

### StateKitAtoms
- ✅ `SKStateAtom` - Mutable global state
- ✅ `SKValueAtom` - Derived read-only atom
- ✅ `SKTaskAtom` - Async computed atom
- ✅ `SKAtomFamily` - Parameterized atoms
- ✅ `useAtom` - Watch atom value
- ✅ `useSetAtom` - Mutate atom
- ✅ `useAtomValue` - Read atom value

### StateKitUI
- ✅ `StateScope` - Hook scope setup
- ✅ `StateView` - Hook-aware view
- ✅ `EnvironmentValues.stateContext` - Environment access

### StateConcurrency
- ✅ `SCTask.retry` - Retry failed operations
- ✅ `SCTask.timeout` - Timeout operations
- ✅ `SCTask.gather` - Parallel execution
- ✅ `AsyncCurrentValueStream` - ValueSubject-like
- ✅ `AsyncPassthroughStream` - PassthroughSubject-like

### StateKitTesting
- ✅ `StateTest` - Hook testing harness

### StateKitMacros
- ✅ `@Atom` - Generate atom boilerplate
- ✅ `@Provider` - Generate provider boilerplate

---

## ⚠️ BETA APIs (Likely Stable, May Change)

### StateKitSupport
- ⚠️ `@HState` - Property wrapper for hooks
- ⚠️ `@HMemo` - Property wrapper memoization
- ⚠️ `@HRef` - Property wrapper for refs
- ⚠️ `@HEnvironment` - Property wrapper for environment

**Status**: Under review, likely to stabilize in v2.1

### StateKitCombine
- ⚠️ `SKPublisherAtom` - Combine publisher bridge
- ⚠️ `asAtom()` - Publisher to atom conversion
- ⚠️ `asPublisher()` - Atom to publisher conversion

**Status**: Testing integration patterns, may adjust API

### StateKitDevTools
- ⚠️ `StateDevScope` - Debug overlay
- ⚠️ State inspection features

**Status**: Enhanced in v2.2 with time-travel debugging

---

## 🚀 EXPERIMENTAL APIs (Active Development)

### Future Features (v2.1+)
- 🚀 `StateKitDebugger` - Time-travel debugging (coming v2.2)
- 🚀 `StateKitProfiler` - Performance profiling (coming v2.2)
- 🚀 State persistence layer (coming v2.3)
- 🚀 SwiftData integration (coming v2.4)

---

## ⚠️ DEPRECATED APIs

### From v1.x
None in v2.0. All v1.x APIs are either kept or replaced with clear migration path.

See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for upgrade instructions.

---

## 🔒 Semantic Versioning Policy

StateKit follows [Semantic Versioning](https://semver.org/):

```
MAJOR.MINOR.PATCH
  |      |      └─ Bug fixes, no API changes
  |      └────────── New features, backward compatible
  └───────────────── Breaking changes
```

### Breaking Change Policy

- Breaking changes only in **MAJOR** releases (3.0, 4.0, etc.)
- Stable APIs maintain compatibility across minor versions
- Beta APIs may change in minor releases
- 3-month deprecation notice required before removal

---

## 🎯 Commitment to Stability

**Stable APIs** are committed to work unchanged for:
- **Minimum**: 2 major versions (v2.x and v3.x)
- **Expected**: 3+ major versions with deprecation notice

**Beta APIs** will reach stability within:
- **Target**: 2 minor versions (e.g., ⚠️ in v2.0 → ✅ in v2.2)

---

## 📞 Reporting Stability Issues

If you find an API is unstable or breaks unexpectedly:

1. **Report Issue**: GitHub Issues with `stability` label
2. **Include Details**: 
   - Exact API and usage
   - Expected vs actual behavior
   - Test case if possible
3. **Response Time**: Triaged within 48 hours

---

## 🔗 Related Documents

- [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) - Upgrade from v1.x
- [CHANGELOG.md](CHANGELOG.md) - Version history
- [API Reference](https://statekit.dev/api) - Complete API docs

---

**Last Updated**: May 17, 2026  
**Next Review**: November 2026 (pre-v2.2)
