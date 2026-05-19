# StateKit V1 Migration Guide

**Target Version**: v1.0.0  
**Release Date**: May 2026  
**Migration Difficulty**: Easy (No breaking changes expected)

---

## ✅ Good News

**StateKit V1 is the current stable release**

If you're using v1.x, you can upgrade with no code changes in most cases.

---

## 🚀 How to Upgrade

### Step 1: Update Package Dependency

In your `Package.swift`:

```swift
// Before
.package(url: "https://github.com/NguyenPhongVN/state-kit", from: "1.0.0")

// After
.package(url: "https://github.com/NguyenPhongVN/state-kit", from: "2.0.0")
```

Or in Xcode: Package Dependencies → StateKit → Version Rules → "Up to Next Major"

### Step 2: Run Your Tests

```bash
swift test
```

All existing tests should pass without modification.

### Step 3: Check for Deprecation Warnings

If you see any deprecation warnings:
- They indicate future changes, but your code still works
- See the specific deprecation message for recommended alternative
- Plan migration before they're removed (3+ versions ahead)

---

## Notable Enhancements in V1

V1 includes the following enhancements you might want to adopt:

### New Riverpods Features

```swift
// NEW: Ecosystem bridge (Atoms ↔ Riverpods)
@Watch(userAtom.asRiverpod()) var user  // Use atoms in Riverpods

@Watch(userProvider.asAtom()) var user  // Use providers in atoms
```

### New Testing Utilities

```swift
// NEW: Enhanced StateTest
let test = StateTest()
test.setState { ... }  // Easier state setup
test.expectEffect { ... }  // Better effect testing
```

### New Macros

```swift
// NEW: @Provider macro (less boilerplate)
@Provider
func userProvider(ref: ProviderRef) -> User {
    ref.watch(userIdProvider)
}

// OLD way still works:
let userProvider = Provider { ref in
    ref.watch(userIdProvider)
}
```

### New Observability

```swift
// NEW: Provider lifecycle observers
container.addObserver(MyObserver())  // Track updates
```

---

## 🔄 If You Used Unstable APIs

If you were using APIs marked as Experimental in v1.x, check [API_STABILITY.md](API_STABILITY.md) for current status.

### Example: Property Wrappers

If you used `@HState` in v1.x:

```swift
// V1 baseline
struct MyView: View {
    @HState var count = 0
    // ...
}

// V1 preferred, more explicit
struct MyView: View {
    @State var count = 0
    // Or use Riverpods for more power
    @Watch(countProvider) var count
}
```

No immediate change needed, but consider migrating over time.

---

## ✅ Compatibility Checklist

- [ ] Updated Package.swift dependency
- [ ] Ran `swift test` - all passing
- [ ] No deprecation warnings in IDE
- [ ] Code compiles and runs
- [ ] All features work as expected

If any issues:
- Check [API_STABILITY.md](API_STABILITY.md) for API changes
- Create issue on GitHub with reproduction case

---

## What's New in V1

See [CHANGELOG.md](CHANGELOG.md) for complete list of:
- New features
- Bug fixes
- Performance improvements
- API additions

---

## 🆘 Need Help?

1. **Documentation**: [StateKit Guide](GUIDE.md)
2. **API Reference**: See individual module docs
3. **GitHub Issues**: Report problems
4. **Examples**: Check /Examples/CaseStudies for usage patterns

---

## 🎯 Recommended Next Steps

1. **Run tests** to verify compatibility
2. **Review new features** in [CHANGELOG.md](CHANGELOG.md)
3. **Adopt new macros** for cleaner code
4. **Plan post-V1 upgrades** when ready:
   - Better composition patterns
   - Architecture guidelines
   - Enhanced DevTools

---

**Upgrade is safe. Enjoy V1!**
