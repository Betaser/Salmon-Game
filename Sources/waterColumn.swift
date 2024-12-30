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
    static var waveCollisionsEnabled = false

    unowned var left: WaterColumn? = nil 
    unowned var right: WaterColumn? = nil 

    enum Disturbance {
        case freelyMoving
        case atEdge
        case beingDisturbed
        func toString() -> String {
            return switch self {
                case .freelyMoving: "freelyMoving"
                case .atEdge: "atEdge"
                case .beingDisturbed: "beingDisturbed"
            }
        }
    }
    var disturbance = Disturbance.freelyMoving
    let disturbanceColors: [Disturbance: Color] = [
        .freelyMoving: Color.blue,
        .atEdge: Color.green,
        .beingDisturbed: Color.orange
    ]   

    var color: Color
    var position: Vector2
    var originalPosition: Vector2
    // up or down, has a similar effect to energy.
    var velocity = Vector2(x: 0, y: 0)
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
    var expectedCrushStartVelocity: Float64
    var id: Int32 = 0
    var showHorz = true
    private var bottom: Float64
    private (set) var verticalZero: Float64
    var restitution: Float64 = -99;

    deinit { refCount -= 1 }

    init(position: Vector2) {
        refCount += 1
        self.position = position
        verticalZero = 0
        originalPosition = position.clone()
        color = Color.blue
        bottom = 0
        expectedCrushStartVelocity = 0
        wave = Wave() 
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
        expectedCrushStartVelocity = 0
        Self.waveCollisionsEnabled = false
        showHorz = true
        restitution = Self.DEFAULT_RESTITUTION 
        disturbance = .freelyMoving

        let horzWaterBuf = Float64(screenWidth - Int32(Simulation.waterColumnCount * Self.WIDTH)) / 2.0
        let id = Int32((position.x - horzWaterBuf) / Float64(Self.WIDTH))
        self.id = id
    }

    func clone() -> WaterColumn {
        let ret = WaterColumn(position: position)
        return ret
    }

    // make sure to nil the wave when you're done with this object!
    var wave: Wave? = nil
    class Wave {
        var lastEdgeVel = 0.0

        // Rejected
        private func alterEdgeVel(column: WaterColumn, awareColumns: some Collection<WaterColumn>) -> () -> Void {
            // vel is inversely proporitional to avg of columns?
            var avgVel = 0.0
            var total = 0.0
            for column in awareColumns {
                if column.disturbance != .beingDisturbed {
                    continue
                }
                total += column.verticalVelocity
                avgVel += abs(column.verticalVelocity)
            }
            avgVel = avgVel / Float64(awareColumns.count) * (total > 0 ? 1 : -1)

            // Because we can't edit owner.verticalVelocity, and as a solution,
            //  I just want to grab the primitives and update later.
            // I would rather have this only kick in when the wave falls below verticalZero.
            return { [self] in 
                column.verticalVelocity += avgVel - lastEdgeVel
                lastEdgeVel = avgVel
            }
        }

        // Rejected
        func alterFreelyMovingVel() {}

        fileprivate func update(data: (Float64, Float64), isNewDip: Bool, column: WaterColumn, awareColumns: some Collection<WaterColumn>) -> (() -> () -> Void) {
            // The wave algo! 
            // Every column that is freelyMoving or atEdge should be held to the same physics
            //  so that the edge columns don't seem out of place. (naive assumption)
            // just code it all inline here, why not.

            /*
            if column.disturbance == .beingDisturbed || 
               column.disturbance == .atEdge ||
               column.disturbance == .freelyMoving {
                // turns every wave semi-slowly into a triangular shape, 
                //  according to the stickyoutnessReq for energy loss
                // Overall, a weird effect that shouldn't necessarily be in here.
                let triangularize = false
                if triangularize {
                    let stickyoutness = 
                        abs(column.position.y - (column.left?.position.y ?? column.position.y)) + 
                        abs(column.position.y - (column.right?.position.y ?? column.position.y)) 
                    let stickyoutnessReq = 3.0
                    if stickyoutness > stickyoutnessReq {
                        // some columns shoot up too much, just have it be slowed down if that happens.
                        let energyRatioLost = 0.0001 * stickyoutness
                        let lostSpeed = column.verticalVelocity * energyRatioLost

                        return { 
                            column.verticalVelocity -= lostSpeed
                            return {} 
                        }
                    }
                }
            }
            */

            // What if we slow down the horizontal wave movement, obv fix this.
            if WaterColumn.waveCollisionsEnabled && Simulation.DEBUG_COUNTER % 1 == 0 {
            // if true || isNewDip {
                func inelasticCollision(restitution: Float64, v: Float64, colliderV: Float64) -> Float64 {
                    return (1 - restitution) / 2.0 * v + (1 + restitution) / 2.0 * colliderV
                }

                // deal with columns who are next to nothing.
                let leftV = column.left?.horzVelocity ?? 0
                let rightV = column.right?.horzVelocity ?? 0
                // let leftV = data.0
                // let rightV = data.1

                let currV = column.horzVelocity
                /*
                // if we are colliding or pushing, do include the velocity in neighboringV
                if (leftV * currV > 0) {
                    // colliding 
                } else {
                    // pushing
                    if (leftV - currV > 0) {
                    }
                }
                */
                // Left/Right velocities are not used if: the column (l/r) does not push 
                //  as much as the current velocity, or if the column (l/r) is moving in the wrong direction.
                // let leftUsed = leftV * currV > 0 || leftV - currV > 0
                // let rightUsed = rightV * currV > 0 || rightV - currV < 0
                let leftUsed = 
                    // colliding/pushing is no different.
                    // obviously colliding case:
                    (leftV > 0 && currV < 0) || 
                    // overall pushing
                    (leftV - currV > 0)
                let rightUsed = 
                    // colliding/pushing is no different.
                    (rightV < 0 && currV > 0) ||
                    // overall pushing
                    (rightV - currV < 0)

                // TODO: Figure out how to propagate a wave one frame at a time. Currently, only the frontmost is kept.
                // Note: Doesn't a horizontal wave that is bigger to the left and going to the right have to flatten into a rectangle?
                // This has not happened in any of my attempts so far.
                // A more reassuring step to complete is that we need the following behavior to be simulated:
                /*
                1. The column in the center is compressed on both sides, and wants to go upwards
                2. The column in the center is kept in a squished state, until the columns next to it are not strong enough to keep it like that
                3. The column in the center would rather unsquish itself than go upwards
                4. All columns can act like the center column
                ???. Does squish affect the width of columns? We would then say the following:
                    - Analyze A B C columns next to each other, where A and C are B's left and right.
                     B expands to even out the right half of A and the left half of C.
                    - Column widths and positions don't vary from the left and right of the unsquished columns (which makes sense)

                It'll be something like:
                - Columns have a squish state amount stored on themselves
                - Squish replaces horizontal velocity
                - Columns either squish more if the sum of the left and right columns press into it strongly enough,
                 otherwise they impart the difference on the left and right columns
                - Columns which are more squished are more resilient to being squished more
                - Columns gain vertical velocity only when they are squished more than the previous frame
                */

                // if we have a column that is "pulling", or the opposite of colliding with another column,
                //  then use a fraction of the velocity.
                let pullingFrac = 0.1
                // When horizontal waves propagate against one another, if pullingFrac is too small then the edge waves go super high.
                let neighboringVWithPull = leftV * (leftUsed ? 1.0 - pullingFrac : pullingFrac) + 
                                   rightV * (rightUsed ? 1.0 - pullingFrac : pullingFrac)
                // This is the money maker. Experiment with this more, it propagates waves forward.
                // let neighboringV = neighboringVWithPull

                /*
                let neighboringVNoPull = leftV * (leftUsed ? 1.0 : 0.0) + 
                                         rightV * (rightUsed ? 1.0 : 0.0)
                let neighboringV = abs(neighboringVWithPull) > abs(neighboringVNoPull) 
                                 ? neighboringVWithPull : neighboringVNoPull
                */

                let neighboringV = leftV * (leftUsed ? 1 : 0) + rightV * (rightUsed ? 1 : 0)

                let collidedVel = inelasticCollision(restitution: 0, v: currV, colliderV: neighboringV)
                // the two expr below are different.
                let otherVel = currV + neighboringV - collidedVel
                // let otherVel = inelasticCollision(v: neighboringV, colliderV: currV)
                // this is not symmetric either:
                // let otherVel = leftV + rightV
                // let otherVel = currV

                // But, we also need to calculate the inelastic collision results for the other columns, 
                // otherwise we just gain speed over time.
                let verticalVel = column.verticalVelocity

                return {
                    if collidedVel != 0 {
                        // print(collidedVel)
                    }
                    // let velChange = abs(collidedVel) - abs(xVel) 
                    let velChange = -abs(otherVel)
                    // Column 12 is the leftmost disturbed column, it and column 13 to its right
                    // achieve a balance of xvel to yvel so that they both go to the right with half the speed 12 had originally.

                    // Controls how fast the wave propagates. Slower = smaller waves, which we want.
                    if Simulation.DEBUG_COUNTER % 5 == 0 {
                        column.horzVelocity = collidedVel
                    }

                    // decay of horzVelocity that is larger for columns that are higher up
                    let aboveZero = column.verticalZero - column.position.y
                    if aboveZero > 0 {
                        column.horzVelocity *= max(0.9, 1 - aboveZero / 3000.0)
                    }


                    if velChange < 0 {
                        // print("change by \(velChange)")
                        column.verticalVelocity = verticalVel + velChange * HORZ_TO_VERT_FACTOR
                    }
                    return {}
                }
            /* Look at paper diagram for more info.
            Key points:
            1. Apply 1D inelastic collision physics with a defined resitution coefficient
            2. Treat the v1 and v2 inputs into the equation as follows:
                i. v1 x velocity of the current column
                ii. v2 x velocity of the sum of the neighboring columns, with rules on "pushing" and "colliding"
            3. After finding the final x velocity, if it is less than the prev frame's, turn that into vertical velocity
            */
            }

            return { return {} }
        }
    }

    func crushedBy(amt: Float64) {
        verticalVelocity += amt
    }

    // f, e, b
    // f, f, e

    // b, e, f
    // e, f, f
    func alterDisturbance(dip: Float64) -> (Disturbance?, Disturbance, Disturbance?) {
        // Basic way to alter disturbance
        var ret: (Disturbance?, Disturbance, Disturbance?) = (left?.disturbance, disturbance, right?.disturbance)
        let disturbanceThreshold = 2.0
        // dip will naturally settle around 4.5!

        if abs(verticalVelocity) < disturbanceThreshold && 
           abs(dip - 4.5) < 1.0 &&
           disturbance == .atEdge {

            // Assume that either the left or right has columns to disturb.
            // Otherwise, if the column is the last .beingDisturbed, it eventually dies
            if let c1 = left, let c2 = right {
                func disturbNeighbors(_ n1: WaterColumn, _ n2: WaterColumn) -> Bool {
                    return n1.disturbance == .freelyMoving && n2.disturbance == .beingDisturbed
                }
                if disturbNeighbors(c1, c2) {
                    ret.2 = .atEdge
                }
                if disturbNeighbors(c2, c1) {
                    ret.0 = .atEdge
                }
            }

            ret.1 = .freelyMoving
        }

        return ret
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
                // invert the color
                let clr = disturbanceColors[disturbance]!
                color = Color(
                    r: UInt8(255 * 0.3 + Float64(clr.r) * 0.7),
                    g: UInt8(255 * 0.3 + Float64(clr.g) * 0.7),
                    b: UInt8(255 * 0.3 + Float64(clr.b) * 0.7),
                    a: clr.a)
                return {}
            })
        }

        verticalVelocity += Self.GRAVITY

        return alterWavePosColor(updatePosAndColor: { [self] in
            position.y += verticalVelocity
            color = disturbanceColors[disturbance]!
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