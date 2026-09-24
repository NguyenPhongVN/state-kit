# StateKit Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### ⚠️ Behavior Changes

- **`ProviderContainer.watch(_:)` is now genuinely reactive** (Riverpod idiom: read = pure,
  watch = reactive). It registers a listener — keeping auto-dispose providers alive — and
  returns the current value; balance every `watch` with `removeListener(for:)`. Previously
  `watch` was an exact synonym of `read` and registered nothing, so callers using it as a
  throwaway read MUST now release the listener (SwiftUI wrappers `@Watch` and `useRiverpod`
  handle this internally and are unaffected).

### Deprecated

- **`ProviderContainer.addListener(for:)`** — exact duplicate of `watch(_:)`; use `watch(_:)`
  balanced with `removeListener(for:)`. No behavior difference; removed at the next MAJOR.

### Fixed

- **Override type mismatches now fail with a precise diagnostic** instead of an unexplained
  cast crash: `ProviderContainer.ensureElement` validates override element/value types and
  names the provider, role, and both types in the failure message.
- Docs: `KeychainStateProvider.clearAll()` documented as deleting exactly its own key (never a
  pattern wipe); the full `preserved(by:)` overload family gained a selection table (nothing
  deprecated, per design decision); new guide `docs/core/HOOKS_VS_MACROS.md` explains when to
  use function hooks vs `@Hook*` macros.
- Public API audit shipped with this feature (`specs/002-clean-public-api/audit.md`): all P1
  findings closed; remaining force-conversions carry written invariant justifications;
  deferred P3 items recorded (per-symbol review of UI/Combine/Testing/Concurrency modules,
  `SKSubscriberToken.Box` surface, `SC*` prefix convention exception).

### Fixed (feature 001 — keychain/cache/rollout)

- **Memory leak in `TimeToLiveCache`, `SlidingWindowTTLCache`, `EventTracker`**: the periodic
  housekeeping/auto-flush task captured `self` strongly in a non-terminating loop and was only
  cancelled in `deinit`, so instances were never deallocated and kept waking the CPU forever.
  The loop now captures `self` weakly and exits as soon as the instance is released. Live
  instances behave unchanged.
- **`KeychainBatch.deleteAll(matching:)` ignored its `pattern` parameter** (and the batch's
  items) and deleted *every* generic-password keychain item the app could access — including
  auth tokens. Deletion is now scoped to the items the batch stored; `pattern` is a prefix
  match, `nil`/empty deletes all batch items. Foreign keychain items are unreachable by
  construction.
- **`KeychainAccessibility` applied invalid `kSecAttrAccessible` values**
  (`"com.apple.keychain.*"` strings are not valid Keychain attributes), making store fail on
  device or set an unintended protection level. Each case now applies the official
  `kSecAttrAccessible*` constant via a new internal `secAttr` mapping.
- **`djb2Hash` mapped every non-ASCII character to 0**, collapsing distinct international
  user IDs (Vietnamese, CJK, Cyrillic, …) onto the same rollout/A-B bucket. The hash now runs
  over the ID's UTF-8 bytes in unsigned 32-bit arithmetic (also removing the `abs(Int.min)`
  trap and negative-modulo hazard).
- **README** stated 47 public macros; the actual count is 48.

### ⚠️ Behavior Changes (feature 001 — accepted, documented)

- `KeychainAccessibility` raw values changed from invented `"com.apple.keychain.*"` strings to
  the platform's canonical codes (`"ak"`, `"aku"`, `"ck"`, `"cku"`, `"dk"`). Hosts persisting
  raw values must remap. Items written by previous builds either failed to store or used an
  unintended protection level, so no migration is possible or needed.
- Rollout/A-B bucket assignments may change for some users due to the `djb2Hash` fix — a
  one-time re-bucketing.

---

## [2.0.0] - May 2026 (Current Release)

### ✨ New Features

#### Riverpods Enhancements
- **Ecosystem Bridge**: Direct interoperability between Atoms and Riverpods
  - New `RiverpodAtom<P>` to wrap providers as atoms
  - New `watch<A: SKAtom>()` method in ProviderRef
  - Use atoms and providers together seamlessly
  
- **AsyncNotifierProvider Improvements**
  - New `.notifier` property to access instance directly
  - Matches `NotifierProvider` API pattern
  - `AsyncNotifierInstanceProvider<N, T>` for instance access
  - Cleaner API for complex async state management

- **Enhanced Lifecycle Observation**
  - `ProviderObserver` protocol for tracking provider events
  - `didAddProvider`, `didUpdateProvider`, `didDisposeProvider` callbacks
  - Built-in logging/analytics/debugging support

- **Selector Providers**
  - New `.select()` method with KeyPath support
  - Only notify dependents when selected value changes
  - Prevents unnecessary rebuilds
  - Example: `@Watch(userProvider.select(\.name))`

#### Testing Improvements
- **Better Provider Testing**
  - Enhanced mock/override support
  - Easier test container setup
  - StateTest harness improvements

- **AsyncValue Enhancements**
  - New `when()` pattern matching method
  - State transitions tracking
  - Better error handling patterns

#### Developer Experience
- **Comprehensive Documentation**
  - Complete API documentation for all modules
  - Professional Riverpods documentation
  - Architecture guide (ARCHITECTURE_GUIDE.md)
  - Examples and use-case docs

- **Swift Macros**
  - `@Atom` macro for atom definition
  - `@Provider` macro for provider definition
  - Significant boilerplate reduction

- **API Stability Documentation**
  - Clear stability levels (Stable/Beta/Experimental)
  - Commitment to API compatibility
  - Deprecation policy documented

#### Code Quality
- **Strict Concurrency Support**
  - Full Swift 6.2 compliance
  - No compiler warnings
  - Thread-safe by default

- **Extended Platform Support**
  - iOS 17+ (primary)
  - macOS 14+ (desktop support)
  - tvOS 17+ (Apple TV support)
  - watchOS 10+ (wearable support)
  - visionOS 1+ (spatial computing)

### 🔧 Bug Fixes
- Fixed type-checking complexity in complex view hierarchies
- Fixed closure self-capture semantics in examples
- Fixed AsyncValue error case destructuring
- Improved compiler performance with ViewBuilder refactoring

### 📚 Documentation
- Riverpods comprehensive documentation completed
- API stability guide (API_STABILITY.md)
- Migration guide for V1 (MIGRATION_GUIDE.md)
- Development roadmap (DEVELOPMENT_ROADMAP.md)
- Example app fixes and improvements

### ✅ What's Stable
- All core Riverpods features
- Complete hooks system
- Atoms system
- StateConcurrency utilities
- Testing framework

### ⚠️ What's Beta
- Property wrappers (@HState, @HMemo, etc.)
- Combine integration
- DevTools debug overlay

See [API_STABILITY.md](API_STABILITY.md) for complete API stability information.

---

## [1.x] - Previous Releases

### v1.5.0
- Initial Riverpod features
- Hooks system foundation
- Atoms system

### v1.0.0
- Initial release
- Core state management
- SwiftUI integration

---

## 📋 Future Planned Features

### Post-V1 Phase 1 (Planned)
- **Architecture Guidelines**: Professional composition patterns
- **Enhanced Composability**: Better module composition
- **Modularity Framework**: Clear boundary definitions

### Post-V1 Phase 2 (Planned)
- **Time-Travel Debugging**: Redux DevTools integration
- **Performance Profiling**: Update frequency tracking
- **Enhanced DevTools**: Live debugging overlay

### Post-V1 Phase 3 (Planned)
- **Advanced Testing**: 100% deterministic testing
- **Test Fixtures**: Pre-built test data generators
- **Integration Tests**: Multi-module testing

### Post-V1 Phase 4 (Planned)
- **E-Commerce Example App**: Production-grade example
- **Architecture Showcase**: Real-world patterns
- **Best Practices Guide**: Expert recommendations

### Post-V1 Phase 5+ (Planned)
- **State Persistence**: Local storage integration
- **SwiftData Bridge**: Database-driven atoms
- **CloudKit Sync**: iCloud synchronization
- **VisionOS Patterns**: Spatial computing support

---

## 🎯 Versioning Policy

StateKit follows [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH**
- **Breaking changes**: MAJOR version bump
- **New features (backward compatible)**: MINOR version bump  
- **Bug fixes**: PATCH version bump

### Stability Commitment
- Stable APIs maintained for **minimum 2 major versions**
- Beta APIs typically reach stability within **2 minor versions**
- Deprecation notice given **3+ versions before removal**

---

## 🙏 Contributors

This release represents the culmination of:
- 187 Swift files of carefully crafted code
- 34 comprehensive test files
- Complete Riverpod feature parity
- Professional-grade documentation

Contributors: Mike Packard and Claude AI assistant team

---

## 📞 Support

- **Documentation**: [GUIDE.md](GUIDE.md), [API_STABILITY.md](API_STABILITY.md)
- **Migration**: [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
- **Issues**: GitHub Issues with appropriate labels
- **Roadmap**: [DEVELOPMENT_ROADMAP.md](DEVELOPMENT_ROADMAP.md)

---

**Current Version**: 2.0.0  
**Release Date**: May 17, 2026  
**Next Review**: next release planning cycle
