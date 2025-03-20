import Foundation
import Raylib
// position at top left
// could consider the center as the position

class WaterColumn {
    static let MASS = 4.5
    // static let SPRING_FACTOR = 0.095
    static let V_SCALE = 0.6
    static let SPRING_FACTOR = 0.085
    // Essentially the default height.
    static let VERTICAL_ZERO = 300.0
    // If gravity is too small, spring force pushes the column upwards at a constant rate.
    static let GRAVITY = 0.105
    // Make sure this is an EVEN number! For at least the disturbance function calculations.
    static let WIDTH: Int32 = 2 * 3
    static let CRUSH_ENERGY_SAVED = 0.95

    unowned var left: WaterColumn? = nil 
    unowned var right: WaterColumn? = nil 

    // Left and right sides
    struct Side {
        var velocity: Vec2
        var horzVel: Float64 {
            set { velocity.x = newValue }
            get { return velocity.x }
        }
        var vertVel: Float64 {
            set { velocity.y = newValue }
            get { return velocity.y }
        }
        var width: Float64
        var size: Float64
        var height: Float64

        init(width: Int32) {
            self.width = Float64(width) / 2.0
            height = Float64(WaterColumn.VERTICAL_ZERO)
            size = self.width * height
            velocity = Vec2(x: 0, y: 0)
        }

        mutating func update(column: WaterColumn) {
            let verticalZero = column.verticalZero
            let dip = verticalZero - height
            let newDip = verticalZero - (height + vertVel)

            if newDip >= 0 {
                let springForce = WaterColumn.SPRING_FACTOR * dip
                let totalForce = springForce + WaterColumn.MASS * -WaterColumn.GRAVITY

                vertVel += totalForce / WaterColumn.MASS
                vertVel *= WaterColumn.CRUSH_ENERGY_SAVED
            } else {
                vertVel += -WaterColumn.GRAVITY
            }

            width -= horzVel
            vertVel += horzVel * 1.6
            height += vertVel

            // Then transfer horzVel to neighbor
            if width < 0.2 * Float64(column.width / 2) {
                if let neighbor = column.right {
                    neighbor.leftSide.horzVel += horzVel
                }
                horzVel = 0
                width = Float64(column.width / 2)
            }
        }

        // this is flipped upside down.
        mutating func update2(column: WaterColumn) {
            let verticalZero = column.verticalZero 
            let dip = height - verticalZero
            let newDip = height + vertVel - verticalZero

            if newDip >= 0 {
                let springForce = -WaterColumn.SPRING_FACTOR * dip
                let totalForce = springForce + WaterColumn.MASS * WaterColumn.GRAVITY

                vertVel += totalForce / WaterColumn.MASS
                vertVel *= WaterColumn.CRUSH_ENERGY_SAVED
            } else {
                vertVel += WaterColumn.GRAVITY
            }


            width -= horzVel

            vertVel += horzVel * 5

            height += vertVel
            // Then transfer horzVel to neighbor
            if width < 0.2 * Float64(column.width / 2) {
                if let neighbor = column.right {
                    neighbor.leftSide.horzVel += horzVel
                }
                horzVel = 0
                width = Float64(column.width / 2)
            }
        }
    }
    // do we want to make width negative for one of the sides? for now only 
    var leftSide: Side
    var rightSide: Side
    var color: Color
    var position: Vec2
    var width: Int32
    var originalPosition: Vec2    
    var id: Int32 = 0
    private (set) var verticalZero: Float64

    let waterColumnCount: Int32
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

    deinit { refCount -= 1 }

    init(position: Vec2, waterColumnCount: Int32, width: Int32) {
        refCount += 1
        self.position = position
        verticalZero = 0
        originalPosition = position.clone()
        color = Color.blue
        wave = Wave() 
        leftSide = Side(width: width / 2)
        rightSide = Side(width: width / 2)
        self.width = width
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

        leftSide.height = position.y
        rightSide.height = position.y
        leftSide.width = Float64(width / 2)
        rightSide.width = Float64(width / 2)

        let horzWaterBuf = Float64(screenWidth - Int32(waterColumnCount * width)) / 2.0
        let id = Int32((position.x - horzWaterBuf) / Float64(width))
        self.id = id
    }

    func clone() -> WaterColumn {
        let ret = WaterColumn(position: position, waterColumnCount: waterColumnCount, width: width)
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
        leftSide.update(column: self)

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

    func render(bottom: Int32, vScale: Float64) {
        var c = color
        c.a = 80

        let height = position.y * vScale
        let y = Float64(bottom) - height
        Raylib.drawRectangleLines(
            Int32(position.x),
            Int32(y),
            width,
            Int32(height),
            c)


        // Render leftSide on top.
        do {
            /*
            let color = if leftSide.width < Float64(width / 2) {
                Color.lime
            } else {
                Color.magenta
            }            
            */
            let newDip = height + leftSide.vertVel - verticalZero
            let color = if newDip >= 0 {
                Color.lime
            } else {
                Color.magenta
            }

            let height = leftSide.height * vScale
            let y = Float64(bottom) - height
            let buffer: Int32 = 2
            Raylib.drawRectangle(
                Int32(position.x) + buffer,
                Int32(y),
                Int32((width - buffer) / 2),
                Int32(height),
                color)
        }
    }
}