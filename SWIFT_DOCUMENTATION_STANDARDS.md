# Swift Professional Documentation Standards

**Quick Reference for StateKit Riverpods Refactoring**

---

## 📐 Basic Structure

```swift
/// One-line summary.
///
/// Extended description with context, use cases, and constraints.
///
/// **Key Points:**
/// - Point 1
/// - Point 2
///
/// **Example:**
/// ```swift
/// // Code example
/// ```
///
/// - Note: Additional information
/// - Important: Critical details
/// - Warning: Potential issues
public ...
```

---

## 📝 Documentation Elements

### For Types (struct, class, enum)

```swift
/// Brief description of what this type represents.
///
/// Extended description explaining:
/// - Purpose and use cases
/// - When to use vs alternatives
/// - Key behaviors and guarantees
///
/// **Lifecycle:**
/// 1. Creation: How instances are created
/// 2. Usage: How instances are used
/// 3. Cleanup: How/when instances are cleaned up
///
/// **Thread Safety:**
/// - Sendable: Can be safely shared across async contexts
/// - @MainActor: Must be accessed from main thread
/// - Thread-safe: Can be accessed from any thread
///
/// **Example: Typical Use Case**
/// ```swift
/// // Real, working code example
/// let instance = TypeName(...)
/// instance.method()
/// ```
///
/// **Example: Advanced Pattern**
/// ```swift
/// // More complex usage
/// ```
///
/// - Note: Side notes or assumptions
/// - Important: Critical constraints
/// - Warning: Common mistakes
/// - See Also: Related types
public struct TypeName {
    // Implementation
}
```

### For Properties

```swift
public struct Example {
    /// Short description of what this property represents.
    ///
    /// Additional details about:
    /// - When it's available
    /// - How it changes
    /// - Constraints on its values
    ///
    /// **Example:**
    /// ```swift
    /// let instance = Example()
    /// print(instance.propertyName)
    /// ```
    ///
    /// - Note: When this value is nil or default
    public let propertyName: Type
}
```

### For Methods

```swift
public struct Example {
    /// Brief description of what this method does.
    ///
    /// Detailed explanation of:
    /// - The operation performed
    /// - Side effects (if any)
    /// - Performance characteristics
    ///
    /// - Parameters:
    ///   - parameter1: Description of this parameter and its constraints
    ///   - parameter2: What values are valid/expected
    /// - Returns: Description of the return value
    /// - Throws: What errors can be thrown and when
    ///
    /// **Example:**
    /// ```swift
    /// let result = instance.methodName(parameter1: value1, parameter2: value2)
    /// ```
    ///
    /// - Note: Additional context
    /// - Complexity: O(n) or performance notes
    public func methodName(parameter1: Type1, parameter2: Type2) -> ResultType {
        // Implementation
    }
}
```

### For Initializers

```swift
public struct Example {
    /// Creates a new instance with the specified configuration.
    ///
    /// This initializer:
    /// - Description of what is set up
    /// - Any validation performed
    /// - Default behaviors
    ///
    /// - Parameters:
    ///   - parameter1: Description and valid range/values
    ///   - parameter2: What this parameter controls
    /// - Throws: What errors might be thrown during initialization
    ///
    /// **Example:**
    /// ```swift
    /// let instance = Example(parameter1: value1, parameter2: value2)
    /// ```
    ///
    /// **Example: With Defaults**
    /// ```swift
    /// let defaultInstance = Example(parameter1: value1)
    /// ```
    public init(parameter1: Type1, parameter2: Type2 = default) {
        // Implementation
    }
}
```

---

## 🏷️ Markup Tags Reference

| Tag | Usage | Example |
|-----|-------|---------|
| `**Bold**` | Emphasis | `**Important:** Never call...` |
| `` `code` `` | Inline code | `the \`watch()\` method` |
| `` ```swift `` | Code blocks | Multi-line code examples |
| `- Note:` | Informational | `- Note: This is optional.` |
| `- Important:` | Critical | `- Important: Thread-safe only...` |
| `- Warning:` | Cautionary | `- Warning: Can cause memory leaks` |
| `- Remark:` | General note | `- Remark: See RFC-2234 for details` |
| `- See Also:` | Related items | `- See Also: RelatedType` |

---

## 📌 MARK Organization

```swift
public class Example {

    // MARK: - Type Definitions
    enum State { }
    typealias Handler = (Value) -> Void

    // MARK: - Properties
    public let publicProperty: Type
    private let privateProperty: Type

    // MARK: - Initialization
    public init(parameter: Type) { }

    // MARK: - Public Methods
    public func publicMethod() { }

    // MARK: - Private Methods
    private func privateMethod() { }

    // MARK: - Protocol Conformance

    // Hashable
    public func hash(into hasher: inout Hasher) { }

    // Equatable
    public static func == (lhs: Example, rhs: Example) -> Bool { }
}
```

---

## 📚 Example Patterns

### Simple Example
```swift
/// **Example:**
/// ```swift
/// let value = fetchData()
/// ```
```

### Complex Example with Setup
```swift
/// **Example: Conditional Logic**
/// ```swift
/// @Provider
/// func dataProvider(ref: ProviderRef) -> Data {
///     let useCache = ref.read(settingsProvider)
///     if useCache {
///         return ref.read(cachedProvider)
///     }
///     return ref.watch(freshProvider)
/// }
/// ```
```

### Before/After Example
```swift
/// **Example: Without Dependencies**
/// ```swift
/// let value = ref.read(provider)
/// // Value won't update if provider changes
/// ```
///
/// **Example: With Dependencies**
/// ```swift
/// let value = ref.watch(provider)
/// // Value automatically updates when provider changes
/// ```
```

### Error Handling Example
```swift
/// **Example: Error Handling**
/// ```swift
/// do {
///     let value = try result.unwrap()
///     print("Success: \(value)")
/// } catch {
///     print("Error: \(error.localizedDescription)")
/// }
/// ```
```

---

## 🎯 Documentation Checklist

### For Every Public Type
- [ ] One-line summary
- [ ] Extended description (2-3 sentences minimum)
- [ ] Use cases or when to use
- [ ] Thread safety (if applicable)
- [ ] At least one example
- [ ] Initialization documented (if not obvious)
- [ ] Key methods documented

### For Every Public Method
- [ ] One-line summary
- [ ] Parameter descriptions
- [ ] Return value description
- [ ] Throws documentation (if applicable)
- [ ] At least one example
- [ ] Important notes or warnings (if applicable)

### For Every Public Property
- [ ] One-line description
- [ ] When it's available/valid
- [ ] Default value if applicable
- [ ] Constraints on values
- [ ] Note if it's immutable or changes

---

## 💻 IDE Integration

### Generate Documentation Stub
```
Option + Command + /
```
Xcode automatically generates documentation template

### View Documentation
```
Option + Click on any symbol
```
Shows full documentation in Quick Help

### Preview Rendered Docs
```
Editor → Rendering Mode → Documentation
```
Shows how documentation appears to users

---

## ✨ Quality Checklist

### Excellent Documentation Has:
- [x] Clear, concise summary
- [x] Examples for common use cases
- [x] Thread safety explicitly stated
- [x] Error cases documented
- [x] Performance notes if relevant
- [x] Warnings for common mistakes
- [x] Cross-references to related types
- [x] Parameter descriptions clear
- [x] Return value fully explained
- [x] Side effects noted

### Poor Documentation:
- ❌ Just restates the code
- ❌ Cryptic or vague descriptions
- ❌ No examples
- ❌ Incomplete parameter docs
- ❌ No mention of errors/throws
- ❌ Thread safety not mentioned
- ❌ Common mistakes not warned about

---

## 🚀 Best Practices

### ✅ DO:
- Provide examples that actually run
- Explain the **why**, not just the **what**
- Document constraints and preconditions
- Include both simple and complex examples
- Explain thread safety explicitly
- Note any side effects
- Cross-reference related types
- Use proper Markdown formatting

### ❌ DON'T:
- Describe implementation details
- Assume reader knows context
- Use vague terms like "something" or "stuff"
- Provide incomplete code snippets
- Document obvious behavior
- Mix languages (stick to English)
- Overuse bold/emphasis
- Create novel-length descriptions

---

## 📋 Template Summary

**Minimal (3 lines):**
```swift
/// Does X to produce Y.
///
/// **Example:**
/// ```swift
/// let result = function(param: value)
/// ```
```

**Standard (10 lines):**
```swift
/// Does X to produce Y.
///
/// Extended explanation with context.
///
/// - Parameters:
///   - param: What it does
/// - Returns: What's returned
///
/// **Example:**
/// ```swift
/// let result = function(param: value)
/// ```
```

**Comprehensive (20+ lines):**
```swift
/// Does X to produce Y.
///
/// Extended explanation with multiple paragraphs
/// covering use cases, constraints, and behaviors.
///
/// **Key Features:**
/// - Feature 1
/// - Feature 2
///
/// **Thread Safety:**
/// Thread-safe description
///
/// - Parameters:
///   - param1: Description
///   - param2: Description
/// - Returns: Detailed return description
/// - Throws: Error scenarios
///
/// **Example: Simple Case**
/// ```swift
/// // Code
/// ```
///
/// **Example: Complex Case**
/// ```swift
/// // Code
/// ```
///
/// - Important: Critical info
/// - Note: Additional notes
/// - Warning: Pitfalls
/// - See Also: RelatedType
```

---

## 🎓 Quick Training

**For File:** `ProviderID.swift`
- Read current implementation
- Add MARK sections
- Write comprehensive documentation
- Add 2-3 usage examples
- Document thread safety
- Validate with Option + Click

**Estimated Time:** 15-20 minutes per file

**Learning Path:**
1. Read refactored examples
2. Follow template
3. Write similar docs
4. Validate in Xcode
5. Repeat with next file

---

## 📞 Questions & Answers

**Q: How long should descriptions be?**
A: 2-3 sentences for basic docs, up to 200 words for complex types

**Q: Should I document implementation details?**
A: No, only document the public contract and behavior

**Q: How many examples do I need?**
A: Minimum 1, better to have simple + complex examples

**Q: What about deprecated APIs?**
A: Use `@available` and explain alternative

**Q: How do I document errors?**
A: Use `- Throws:` section with error types and conditions

---

**Standard Applied:** Apple Swift API Design Guidelines  
**Quality Target:** 5-star documentation for IDE integration  
**Time Investment:** Worth it for long-term maintainability
