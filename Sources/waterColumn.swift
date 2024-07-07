import Raylib
// position at top left
// could consider the center as the position

class WaterColumn {
    static let MASS = 4.5
    static let SPRING_FACTOR = 0.2
    static let VERTICAL_ZERO = 300.0
    static let GRAVITY = 0.045
    static let WIDTH = 20
    static let HEIGHT = 200
    static let CRUSH_ENERGY_SAVED = 0.95

    // debugging
    private var color: Color
    var position: Vector2
    var originalPosition: Vector2
    // up or down, has a similar effect to energy.
    var verticalVelocity: Float64
    private (set) var verticalZero: Float64

    init(position: Vector2) {
        self.position = position
        verticalVelocity = 0
        verticalZero = 0
        originalPosition = position
        color = Color.blue
        reinit()
    }

    func reinit() {
        position = originalPosition
        verticalVelocity = 0
        verticalZero = WaterColumn.VERTICAL_ZERO
        color = Color.blue
    }

    func crushedBy(amt: Float64) {
        verticalVelocity += amt
    }

    func update() {
        let dip = position.y - verticalZero 
        let newDip = position.y + verticalVelocity - verticalZero

        // A crush disruption can only occur here.
        if newDip > 0 {
            // A fraction of dip.
            let springForce = -WaterColumn.SPRING_FACTOR * dip
            let totalForce = springForce + WaterColumn.MASS * WaterColumn.GRAVITY

            verticalVelocity += totalForce / WaterColumn.MASS
            verticalVelocity *= WaterColumn.CRUSH_ENERGY_SAVED
            position.y += verticalVelocity
            
            // being crushed
            color = Color.orange

            return
        }

        verticalVelocity += WaterColumn.GRAVITY
        position.y += verticalVelocity

        // in the air
        color = Color.blue
    }

    func render() {
        Raylib.drawRectangle(Int32(position.x), Int32(position.y), Int32(WaterColumn.WIDTH), Int32(WaterColumn.HEIGHT), color)
    }
}