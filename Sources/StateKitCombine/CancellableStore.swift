import ObjectiveC
import Combine

nonisolated(unsafe) private var cancellablesKey: UInt8 = 0

// MARK: - CancellableStore
protocol CancellableStore: AnyObject {}

// MARK: - CancellableStore
extension CancellableStore {
    var cancellables: Set<AnyCancellable> {
        get {
            if let set = objc_getAssociatedObject(self, &cancellablesKey) as? Set<AnyCancellable> {
                return set
            }

            let set = Set<AnyCancellable>()
            objc_setAssociatedObject(
                self,
                &cancellablesKey,
                set,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            return set
        }

        set {
            objc_setAssociatedObject(
                self,
                &cancellablesKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

// MARK: - AnyCancellable
extension AnyCancellable {
    func store<Object: CancellableStore>(in object: Object) {
        var cancellables = object.cancellables
        cancellables.insert(self)
        object.cancellables = cancellables
    }
}
