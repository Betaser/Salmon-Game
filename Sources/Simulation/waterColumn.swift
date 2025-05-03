import Foundation
import Raylib
// position at top left
// could consider the center as the position

class WaterColumn : ClosureSeq {
    typealias T = WaterColumn
    typealias G = Getter
    typealias S = Setter

    static let MASS = 4.5
    // static let SPRING_FACTOR = 0.095
    static let V_SCALE = 0.6
    static let SPRING_FACTOR = 0.035
    // Essentially the default height.
    static let VERTICAL_ZERO = 300.0
    // If gravity is too small, spring force pushes the column upwards at a constant rate.
    static let GRAVITY = 0.105
    // Make sure this is an EVEN number! For at least the disturbance function calculations. 2 * 3
    static let WIDTH: Int32 = 12
    static let CRUSH_ENERGY_SAVED = 0.97
    static let VERT_BOOST_FACTOR_FROM_HORZ = 1.6

    unowned var left: WaterColumn? = nil 
    unowned var right: WaterColumn? = nil 

    class Vacuum {
        var emptyAmt: Float64
        var fillAmt: Float64
        var combinedYet: Bool

        var strength: Float64 {
            get {
                return emptyAmt - fillAmt
            }
        }

        init(strength: Float64) {
            emptyAmt = strength
            fillAmt = 0
            combinedYet = false
        }
    }

    // Instances of waves will contain all of our per wave data
    class Wave {
        var vacuum: Vacuum?
        unowned var left: Wave? = nil
        unowned var right: Wave? = nil
        var leftX: Float64
        var rightX: Float64
        var width: Float64
        var velocity: Vec2
        var deltaHorzVel: Float64
        var horzVel: Float64 {
            set { velocity.x = newValue }
            get { return velocity.x }
        }
        var vertVel: Float64 {
            set { velocity.y = newValue }
            get { return velocity.y }
        }
        var height: Float64

        // leftX = 0 to half width
        // rightX = half width to width
        init(width: Float64, height: Float64) {
            self.width = width
            leftX = 0
            rightX = width
            velocity = Vec2(x: 0, y: 0)
            deltaHorzVel = 0
            self.height = height
            vacuum = nil
        }

        func tryAddToVacuum(column: WaterColumn) -> () -> Void {
            let belowZero = height - column.verticalZero < 0

            if belowZero {
                let dip = column.verticalZero - height
                let emptyAmt = dip * 1.3
                if let vac = vacuum {
                    // air fills in the vacuum
                    vac.emptyAmt = emptyAmt
                    vac.fillAmt = min(vac.emptyAmt, 0.5 * (vac.emptyAmt - vac.fillAmt) + 0.05)
                } else {
                    print("amt is \(emptyAmt)")
                    vacuum = Vacuum(strength: emptyAmt)
                }
            } else {
                vacuum = nil
            }

            vacuum?.combinedYet = false
            print("tryAdd1 \(column.id)")

            // Now we render the vacuums to check?

            // unowned self?
            return { [self] in
                print("tryAdd2 \(column.id)")
                // 5 (was nil but is 1 on this frame) 4
                // 10 10 10 (share same vacuum) 
                // Best way I can think of this is that the leftmost and earlier column combines vacuums ahead of it
                // And store a combinedYet Bool on vacuum that is set by the leftmost column and unset on a column

                // Go right
                // BUT ERROR, this closure executes in reverse order!
                // Likely was set to true from a leftmost column doing the code above.
                if !(vacuum?.combinedYet ?? true) {
                    var col = column
                    if let vac = col.wave.vacuum {
                        print("so combinedyet is false right \(vac.combinedYet)")
                        vac.combinedYet = true
                        while let c = col.right {
                            if let rightVac = c.right?.wave.vacuum {
                                vac.emptyAmt += rightVac.emptyAmt
                                vac.fillAmt += rightVac.fillAmt
                                c.wave.vacuum = vac
                            } else {
                                break
                            }
                            col = c.right.unsafelyUnwrapped
                        }
                        print("go to the right and see their combinedYet vals")
                        // We only have a column to the right every odd column id?
                        col = column
                        while let c = col.right {
                            print("ans: \(c.wave.vacuum?.combinedYet ?? false)")
                            if c.right?.wave.vacuum == nil {
                                break
                            }
                            col = c.right.unsafelyUnwrapped
                        }
                        print("resulting combined is \(vac.strength)")
                    }

                }
            }
        }

        func tryAddToVacuumGAS() -> ((Getter) -> Void, (Setter) -> Void) {
            var belowZero = false

            let g = { [unowned self] (getter: Getter) -> Void in
                belowZero = height - getter.verticalZero < 0

                if belowZero {
                    let dip = getter.verticalZero - height
                    let emptyAmt = dip * 1.3
                    if let vac = vacuum {
                        // air fills up the vacuum
                        vac.emptyAmt = emptyAmt
                        vac.fillAmt = min(vac.emptyAmt, 0.8 * abs(vac.emptyAmt - vac.fillAmt) + vac.fillAmt + 0.05)
                    } else {
                        // print("amt is \(emptyAmt)")
                        vacuum = Vacuum(strength: emptyAmt)
                    }
                } else {
                    vacuum = nil
                }

                vacuum?.combinedYet = false
                // print("tryAddGetter \(column.id)")
            }

            let s = { [unowned self] (setter: Setter) -> Void in
                // print("tryAddSetter \(column.id)")
                if let vac = vacuum, !vac.combinedYet {
                    let column = setter.owner.unsafelyUnwrapped
                    var col = column
                    // print("col id \(col.id)")
                    vac.combinedYet = true
                    var leftCount = 0
                    while let left = col.left {
                        if let v = left.wave.vacuum {
                            vac.emptyAmt += v.emptyAmt
                            vac.fillAmt += v.fillAmt
                            left.wave.vacuum = vac
                        }
                        leftCount += 1
                        col = left
                    }
                    
                    // print("col \(column.id) went left \(leftCount) times")
                }
            }

            return (g, s)
        }

        func update(column: WaterColumn) -> () -> Void {
            let verticalZero = column.verticalZero
            let dip = verticalZero - height
            let newDip = verticalZero - (height + vertVel)
            
            var vVel = vertVel
            var hVel = horzVel
            var lX = leftX 
            var rX = rightX
            var h = height

            if newDip >= 0 {
                let springForce = WaterColumn.SPRING_FACTOR * dip
                let totalForce = springForce + WaterColumn.MASS * -WaterColumn.GRAVITY

                vVel += totalForce / WaterColumn.MASS
                vVel *= WaterColumn.CRUSH_ENERGY_SAVED
            } else {
                vVel += -WaterColumn.GRAVITY
            }

            if hVel > 0 {
                lX += hVel
            } else if hVel < 0 {
                rX += hVel
            }

            vVel += abs(hVel) * 1.6
            h += vVel
            

            // Transfer horzVel to correct neighbor. Requires the receiving neighbor to be on the lookout for it
            if rX < width / 2 {
                if let neighbor = column.left {
                    neighbor.wave.deltaHorzVel += horzVel
                }
                hVel = 0
                rX = width
            }

            if lX > width / 2 {
                if let neighbor = column.right {
                    neighbor.wave.deltaHorzVel += horzVel
                }
                hVel = 0
                lX = 0
            }

            return { [unowned self] in
                vertVel = vVel
                // Transfer horzVel to correct neighbor
                horzVel = hVel + deltaHorzVel
                deltaHorzVel = 0
                leftX = lX
                rightX = rX
                height = h
            }
        }

        func updateGAS() -> ((Getter) -> Void, (Setter) -> Void) {
            var vVel: Float64 = 0
            var hVel: Float64 = 0
            var lX: Float64 = 0
            var rX: Float64 = 0
            var h: Float64 = 0

            let g = { [unowned self] (getter: Getter) -> Void in
                let verticalZero = getter.verticalZero
                let dip = verticalZero - height
                let newDip = verticalZero - (height + vertVel)

                vVel = getter.waveVertVel
                hVel = getter.waveHorzVel
                lX = getter.waveLeftX
                rX = getter.waveRightX
                h = getter.waveHeight

                if newDip >= 0 {
                    let springForce = WaterColumn.SPRING_FACTOR * dip
                    let totalForce = springForce + WaterColumn.MASS * -WaterColumn.GRAVITY

                    vVel += totalForce / WaterColumn.MASS
                    vVel *= WaterColumn.CRUSH_ENERGY_SAVED
                } else {
                    vVel += -WaterColumn.GRAVITY
                }

                if hVel > 0 {
                    lX += hVel
                } else if hVel < 0 {
                    rX += hVel
                }

                vVel += abs(hVel) * WaterColumn.VERT_BOOST_FACTOR_FROM_HORZ
                h += vVel

                if rX < width / 2 {
                    if let neighbor = getter.owner?.left {
                        neighbor.wave.deltaHorzVel += horzVel
                    }
                    hVel = 0
                    rX = width
                }

                if lX > width / 2 {
                    if let neighbor = getter.owner?.right {
                        neighbor.wave.deltaHorzVel += horzVel
                    }
                    hVel = 0
                    lX = 0
                }
            }

            let s = { [unowned self] (setter: Setter) -> Void in
                setter.setWaveVertVel(vVel)
                setter.setWaveHorzVel(hVel + deltaHorzVel)
                setter.setDeltaHorzVel(0)
                setter.setWaveLeftX(lX)
                setter.setWaveRightX(rX)
                setter.setWaveHeight(h)
            }

            return (g, s)
        }
    }

    class Setter {
        weak var owner: WaterColumn? = nil
        func setWaveVertVel(_ val: Float64) {
            owner?.wave.vertVel = val
        }
        func setDeltaHorzVel(_ val: Float64) {
            owner?.wave.deltaHorzVel = val
        }
        func setWaveHorzVel(_ val: Float64) {
            owner?.wave.horzVel = val
        }
        func setWaveHeight(_ val: Float64) {
            owner?.wave.height = val
        }
        func setWaveLeftX(_ val: Float64) {
            owner?.wave.leftX = val
        }
        func setWaveRightX(_ val: Float64) {
            owner?.wave.rightX = val
        }
    }

    class Getter {
        weak var owner: WaterColumn? = nil
        var verticalZero: Float64 {
            get { return owner?.verticalZero ?? 0 }
        }
        var waveVertVel: Float64 {
            get { return owner?.wave.vertVel ?? 0 }
        }
        var waveHorzVel: Float64 {
            get { return owner?.wave.horzVel ?? 0 }
        }
        var waveHeight: Float64 {
            get { return owner?.wave.height ?? 0 }
        }
        var waveLeftX: Float64 {
            get { return owner?.wave.leftX ?? 0 }
        }
        var waveRightX: Float64 {
            get { return owner?.wave.rightX ?? 0 }
        }
    }

    var wave: Wave
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
    var g: Getter
    var s: Setter

    deinit { refCount -= 1 }

    init(position: Vec2, waterColumnCount: Int32, width: Int32) {
        refCount += 1
        self.position = position
        verticalZero = 0
        originalPosition = position.clone()
        color = Color.blue
        wave = Wave(width: Float64(width), height: position.y)
        self.width = width
        self.waterColumnCount = waterColumnCount
        g = Getter()
        s = Setter()
        reinit()
        g.owner = self
        s.owner = self
    }

    func reinit() {
        position = originalPosition.clone()
        verticalVelocity = 0
        verticalZero = Self.VERTICAL_ZERO
        horzVelocity = 0
        velocity.y = 0
        color = Color.blue

        wave.width = Float64(width)
        wave.leftX = 0
        wave.rightX = wave.width

        let horzWaterBuf = Float64(screenWidth - Int32(waterColumnCount * width)) / 2.0
        let id = Int32((position.x - horzWaterBuf) / Float64(width))
        self.id = id
    }

    func clone() -> WaterColumn {
        let ret = WaterColumn(position: position, waterColumnCount: waterColumnCount, width: width)
        return ret
    }

    typealias AllGAS = [(UInt, ((Getter) -> Void, (Setter) -> Void))]
    func updateGAS() -> (UInt, DistAndGAS) {
        let allGAS = allGetAndSets()
        assert(true, "todo updategas")
        return indexExprsAndMaxGAS(exprs: allGAS)
    }

    func allGetAndSets() -> [((Getter) -> Void, (Setter) -> Void)?] {
        // Need to update wave.
        let waveUpdate = wave.updateGAS()
        let waveTryAddToVacuum = wave.tryAddToVacuumGAS()
        assert(true, "todo allgetsandsets")
        return [waveUpdate, waveTryAddToVacuum]
    }

    var getter: Getter {
        get { return g }
    }
    var setter: Setter {
        get { return s }
    }

    func update() -> (UInt, UpdateClosures) {
        // Nasty code
        let waveAlter: (() -> () -> Void)? = { [self] in
            return wave.update(column: self)
        }
        let vacuum: (() -> () -> Void)? = { [self] in
            return wave.tryAddToVacuum(column: self)
        }
        return indexExprsAndMax(exprs: [
            waveAlter,
            vacuum
        ])
    }

    func render(bottom: Int32, vScale: Float64) {
        var c = color
        c.a = 80

        let waterColumnHeight = position.y * vScale

        // I don't remember what this is for
        if false {
            let height = position.y * vScale
            let y = Float64(bottom) - height
            Raylib.drawRectangleLines(
                Int32(position.x),
                Int32(y),
                width,
                Int32(height),
                c)
        }

        // Render wave
        let newDip = wave.height + wave.vertVel - verticalZero
        let color = if newDip >= 0 {
            Color.lime
        } else {
            Color.magenta
        }

        let height = wave.height * vScale
        let y = Float64(bottom) - height
        let buffer: Int32 = 2
        Raylib.drawRectangle(
            Int32(position.x) + buffer,
            Int32(y),
            Int32((width - buffer) / 2),
            Int32(height),
            color)

        // Render vacuum
        do {
            if let vacuum = wave.vacuum {
                let vacColor = if left?.wave.vacuum != nil && right?.wave.vacuum != nil {
                    Color.yellow
                } else {
                    Color.gold
                }

                // Cast double to Int32 smaller than Int32 min
                let HEIGHT = Float64(vacuum.strength * 2.5)
                // print(HEIGHT)
                // let HEIGHT = 40.0
                let GAP = 15.0
                Raylib.drawRectangle(
                    Int32(position.x) + buffer,
                    Int32(y - HEIGHT - GAP),
                    Int32((width - buffer) / 2),
                    Int32(HEIGHT),
                    vacColor)
            }
        }
    }
}