actor RevisionClock {

    private var counter: UInt64 = 0

    func next() -> Revision {
        counter &+= 1
        return Revision(value: counter)
    }
}
