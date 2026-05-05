struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(state: UInt64) {
        self.state = state == 0 ? 0x9E3779B97F4A7C15 : state
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
