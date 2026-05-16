import StateKit

// MARK: - @AtomFamily with Multiple Parameters

@AtomFamily
struct UserProfileAtom {
    let userId: String
    let theme: String
    
    func defaultValue(context: AtomContext) -> UserProfile {
        UserProfile(id: userId, theme: theme)
    }
}

/*
Generates:
public struct UserProfileAtomID: Hashable, Sendable {
    public let userId: String
    public let theme: String
    public init(userId: String, theme: String) {
        self.userId = userId
        self.theme = theme
    }
}

private let _userProfileAtomFamily = atomFamily { (id: UserProfileAtomID) in
    UserProfileAtom(userId: id.userId, theme: id.theme)
}

public func userProfileAtom(userId: String, theme: String) -> some SKStateAtom {
    _userProfileAtomFamily(UserProfileAtomID(userId: userId, theme: theme))
}
*/

// Usage in View:
// @SKState(userProfileAtom(userId: "123", theme: "dark")) var profile

---

// MARK: - @SelectorFamily with Multiple Parameters

@SelectorFamily
struct UserSettingsSelector {
    let category: String
    let filter: String
    
    func value(context: AtomContext) -> [Setting] {
        let allSettings = context.watch(AllSettingsAtom())
        return allSettings.filter { $0.category == category && $0.name.contains(filter) }
    }
}

/*
Generates:
public struct UserSettingsSelectorID: Hashable, Sendable {
    public let category: String
    public let filter: String
    public init(category: String, filter: String) {
        self.category = category
        self.filter = filter
    }
}

private let _userSettingsSelectorFamily = selectorFamily { (id: UserSettingsSelectorID, context: SKAtomTransactionContext) in
    UserSettingsSelector(category: id.category, filter: id.filter).value(context: context)
}

public func userSettingsSelector(category: String, filter: String) -> some SKValueAtom {
    _userSettingsSelectorFamily(UserSettingsSelectorID(category: category, filter: filter))
}
*/

// Usage in View:
// @SKValue(userSettingsSelector(category: "privacy", filter: "location")) var settings
