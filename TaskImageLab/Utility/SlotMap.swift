struct SlotMapHandle: Hashable, Sendable {
    let index: Int32
    let generation: Int32

    static let invalid = SlotMapHandle(index: 0, generation: 0)

    var isValid: Bool {
        index != 0 && generation != 0
    }
}

struct SlotMap<Value: AnyObject> {
    private var entries: [Entry?] = [nil]
    private var freeIndices: [Int32] = []

    mutating func insert(_ value: Value) -> SlotMapHandle {
        if let freeIndex = freeIndices.popLast() {
            guard let index = Int(exactly: freeIndex), entries.indices.contains(index) else {
                return .invalid
            }

            let generation = nextGeneration(for: entries[index])
            entries[index] = Entry(generation: generation, value: value)
            return SlotMapHandle(index: freeIndex, generation: generation)
        }

        guard entries.count < Int(Int32.max) else {
            return .invalid
        }

        let index = entries.count
        entries.append(Entry(generation: 1, value: value))
        return SlotMapHandle(index: Int32(index), generation: 1)
    }

    func get(_ handle: SlotMapHandle) -> Value? {
        guard
            let entry = entry(for: handle)
        else {
            return nil
        }

        return entry.value
    }

    @discardableResult
    mutating func remove(for handle: SlotMapHandle) -> Value? {
        guard let index = index(for: handle) else {
            return nil
        }

        let value = entries[index]?.value
        entries[index] = nil
        freeIndices.append(handle.index)
        return value
    }

    func handles() -> [SlotMapHandle] {
        entries.enumerated().compactMap { index, entry in
            guard let entry else {
                return nil
            }

            return SlotMapHandle(
                index: Int32(index),
                generation: entry.generation
            )
        }
    }

    private func entry(for handle: SlotMapHandle) -> Entry? {
        guard
            handle.isValid,
            let index = index(for: handle),
            let entry = entries[index],
            entry.generation == handle.generation
        else {
            return nil
        }

        return entry
    }

    private func index(for handle: SlotMapHandle) -> Int? {
        guard
            handle.isValid,
            let index = Int(exactly: handle.index),
            entries.indices.contains(index)
        else {
            return nil
        }

        return index
    }

    private func nextGeneration(for entry: Entry?) -> Int32 {
        guard let entry else {
            return 1
        }

        if entry.generation == Int32.max {
            return 1
        }

        return entry.generation + 1
    }

    private struct Entry {
        let generation: Int32
        var value: Value
    }
}
