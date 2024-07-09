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