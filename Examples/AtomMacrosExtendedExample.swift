import StateKit

// MARK: - @SelectorAtom Example

/// Generates: typealias Value = Bool
@SelectorAtom
struct IsAdultAtom {
    func select(context: AtomContext) -> Bool {
        let user = context.watch(UserAtom())
        return user.age >= 18
    }
}

// Usage: context.value(IsAdultAtom())
// More semantic than @ValueAtom for derived selections

---

// MARK: - @FilteredAtom Example

/// Auto-filters a list of users to only active ones
@FilteredAtom
struct ActiveUsersAtom {
    func predicate(_ user: User) -> Bool {
        user.isActive
    }
}

// Usage: context.value(ActiveUsersAtom())
// Generates: typealias Value = [T]

---

// MARK: - @MappedAtom Example

/// Auto-transforms list of users to just their names
@MappedAtom
struct UserNamesAtom {
    func transform(_ user: User) -> String {
        user.name.uppercased()
    }
}

// Usage: context.value(UserNamesAtom())
// Transforms: [User] -> [String]
