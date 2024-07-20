class Vector2 {
    var x: Float64
    var y: Float64
    init(x: Float64, y: Float64) {
        self.x = x
        self.y = y
    }
    func clone() -> Vector2 {
        return Vector2(x: x, y: y)
    }
}

extension Collection {
    // Some collections do not use Ints as Indices
    func get(_ i: Int) -> Element? where Index == Int {
        let offset = i >= 0 ? i : i + count
        if offset >= count {
            return nil
        }
        // Use startIndex in case the current collection is a slice
        return self[index(startIndex, offsetBy: offset)]
    }
}

struct Generic {
    func staticCreate<T>(_ mkObj: () -> T) -> T {
        refCount -= 1
        return mkObj()
    }
    static let inst = Self()
}