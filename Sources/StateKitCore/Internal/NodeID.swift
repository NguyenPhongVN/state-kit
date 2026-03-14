struct NodeID: Hashable, Sendable {

    private let raw: ObjectIdentifier

    init(_ object: AnyObject) {
        self.raw = ObjectIdentifier(object)
    }
}
