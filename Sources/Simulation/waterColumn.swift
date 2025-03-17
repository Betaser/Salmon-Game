import Foundation
import Raylib
// position at top left
// could consider the center as the position

class WaterColumn {
    static let DEFAULT_RESTITUTION = 0.98
    static let MASS = 4.5
    // static let SPRING_FACTOR = 0.095
    static let SPRING_FACTOR = 0.045
    static let VERTICAL_ZERO = 300.0
    static let GRAVITY = 0.105
    // static let WIDTH = 20
    // Make sure this is an EVEN number! For at least the disturbance function calculations.
    static let WIDTH = 2 * 3
    static let HEIGHT = 200
    // static let CRUSH_ENERGY_SAVED = 0.99
    static let CRUSH_ENERGY_SAVED = 0.95
    static let HORZ_TO_VERT_FACTOR = 0.15

    unowned var left: WaterColumn? = nil 
    unowned var right: WaterColumn? = nil 

    var color: Color
    var position: Vec2
    var originalPosition: Vec2
    // up or down, has a similar effect to energy.
    var velocity = Vec2(x: 0, y: 0)
    var horzVelocity: Float64 {
        set(val) {
            velocity.x = val
        }
        get {
            return velocity.x
        }
    }
    var verticalVelocity: Float64 {
        set(val) {
            velocity.y = val
        }
        get {
            return velocity.y
        }
    }
    var id: Int32 = 0
    var showHorz = true
    private var bottom: Float64
    private (set) var verticalZero: Float64
    var restitution: Float64 = -99;
    let waterColumnCount: Int

    deinit { refCount -= 1 }

    init(position: Vec2, waterColumnCount: Int) {
        refCount += 1
        self.position = position
        verticalZero = 0
        originalPosition = position.clone()
        color = Color.blue
        bottom = 0
        wave = Wave() 
        self.waterColumnCount = waterColumnCount
        reinit()
    }

    func reinit() {
        position = originalPosition.clone()
        verticalVelocity = 0
        verticalZero = Self.VERTICAL_ZERO
        horzVelocity = 0
        velocity.y = 0
        color = Color.blue
        bottom = position.y + Float64(Self.HEIGHT)
        showHorz = true
        restitution = Self.DEFAULT_RESTITUTION 

        let horzWaterBuf = Float64(screenWidth - Int32(waterColumnCount * Self.WIDTH)) / 2.0
        let id = Int32((position.x - horzWaterBuf) / Float64(Self.WIDTH))
        self.id = id
    }

    func clone() -> WaterColumn {
        let ret = WaterColumn(position: position, waterColumnCount: waterColumnCount)
        return ret
    }

    // make sure to nil the wave when you're done with this object!
    var wave: Wave? = nil
    class Wave {
        var lastEdgeVel = 0.0

        fileprivate func update(data: (Float64, Float64), isNewDip: Bool, column: WaterColumn, awareColumns: some Collection<WaterColumn>) -> (() -> () -> Void) {
            // The wave algo! 

            return { return {} }
        }
    }

    func update(data: (Float64, Float64), awareColumns: some Collection<WaterColumn>) -> (UInt, UpdateClosures) {
        let dip = position.y - verticalZero 
        let newDip = position.y + verticalVelocity - verticalZero
        // generally, make newDip have a bit of a buffer.

        let dipBuffer = -0.0

        let isNewDip = newDip >= dipBuffer && dip < dipBuffer
        func alterWavePosColor(updatePosAndColor: @escaping () -> () -> Void) -> (UInt, UpdateClosures) {
            // now let's try to have the concept of waves
            let waveAlter: (() -> () -> Void)? = if let wave = wave {
                wave.update(data: data, isNewDip: isNewDip, column: self, awareColumns: awareColumns)
            } else {
                nil
            }
            return indexExprsAndMax(exprs: [
                waveAlter,
                updatePosAndColor,
            ])
        }

        // When Underwater, spring back upwards
        // A crush disruption can only occur here.
        // Note that wave.update is ran whether or not this if statement runs!
        if newDip >= dipBuffer {
            // A fraction of dip.
            let springForce = -Self.SPRING_FACTOR * dip
            let totalForce = springForce + Self.MASS * Self.GRAVITY

            verticalVelocity += totalForce / Self.MASS
            verticalVelocity *= Self.CRUSH_ENERGY_SAVED
 
            // being crushed

            return alterWavePosColor(updatePosAndColor: { [self] in 
                position.y += verticalVelocity
                return {}
            })
        }

        verticalVelocity += Self.GRAVITY

        return alterWavePosColor(updatePosAndColor: { [self] in
            position.y += verticalVelocity
            return {}
        })
    }

    func render() {
        // It's kinda too big right now, make the vertical size smaller.
        let V_SCALE = 0.3
        Raylib.drawRectangle(Int32(position.x), Int32((1 - V_SCALE) * verticalZero + V_SCALE * position.y), Int32(Self.WIDTH), Int32(bottom - ((1 - V_SCALE) * verticalZero + V_SCALE * position.y)), color)
        Raylib.drawRectangleLines(Int32(position.x), Int32((1 - V_SCALE) * verticalZero + V_SCALE * position.y), Int32(Self.WIDTH), Int32(bottom - ((1 - V_SCALE) * verticalZero + V_SCALE * position.y)), Color.yellow)

        if showHorz {
            let minHeight: Float64 = 30
            if horzVelocity > 0 {
                // green above bottom - 20
                Raylib.drawRectangle(Int32(position.x), Int32(bottom - 20 - 20 * horzVelocity), Int32(Self.WIDTH - 2), Int32(20 * abs(horzVelocity) + minHeight), Color(r: 100, g: 255, b: 0, a: 255))
            } else {
                // magenta below bottom - 20
                Raylib.drawRectangle(Int32(position.x), Int32(bottom - 20), Int32(Self.WIDTH - 2), Int32(20 * -horzVelocity + minHeight), Color.magenta)
            }
        }
    }
}