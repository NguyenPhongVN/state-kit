# StateKit Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Migration guide for v1.x → v2.0 (MIGRATION_GUIDE.md)
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

### v2.1 (Planned: Q3 2026)
- **Architecture Guidelines**: Professional composition patterns
- **Enhanced Composability**: Better module composition
- **Modularity Framework**: Clear boundary definitions

### v2.2 (Planned: Q4 2026)
- **Time-Travel Debugging**: Redux DevTools integration
- **Performance Profiling**: Update frequency tracking
- **Enhanced DevTools**: Live debugging overlay

### v2.3 (Planned: Q1 2027)
- **Advanced Testing**: 100% deterministic testing
- **Test Fixtures**: Pre-built test data generators
- **Integration Tests**: Multi-module testing

### v2.4 (Planned: Q2 2027)
- **E-Commerce Example App**: Production-grade example
- **Architecture Showcase**: Real-world patterns
- **Best Practices Guide**: Expert recommendations

### v2.5+ (Planned: Beyond Q2 2027)
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
**Next Review**: November 2026 (pre-v2.1)
