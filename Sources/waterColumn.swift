import Raylib
// position at top left
// could consider the center as the position

class WaterColumn {
    static let MASS = 4.5
    static let SPRING_FACTOR = 0.045
    static let VERTICAL_ZERO = 300.0
    static let GRAVITY = 0.045
    // static let WIDTH = 20
    // Make sure this is an EVEN number! For at least the disturbance function calculations.
    static let WIDTH = 4
    static let HEIGHT = 200
    static let CRUSH_ENERGY_SAVED = 0.99

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
        .beingDisturbed: Color.yellow
    ]   

    var color: Color
    var position: Vector2
    var originalPosition: Vector2
    // up or down, has a similar effect to energy.
    var velocity = Vector2(x: 0, y: 0)
    var verticalVelocity: Float64 {
        set(val) {
            velocity.y = val
        }
        get {
            return velocity.y
        }
    }
    var expectedCrushStartVelocity: Float64
    private var bottom: Float64
    private (set) var verticalZero: Float64

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
        color = Color.blue
        bottom = position.y + Float64(Self.HEIGHT)
        expectedCrushStartVelocity = 0
        disturbance = .freelyMoving
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

        fileprivate func update(isNewDip: Bool, column: WaterColumn, awareColumns: some Collection<WaterColumn>) -> () -> Void {
            // The wave algo! 
            // Every column that is freelyMoving or atEdge should be held to the same physics
            //  so that the edge columns don't seem out of place. (naive assumption)
            // just code it all inline here, why not.

            if column.disturbance == .beingDisturbed || 
               column.disturbance == .atEdge ||
               column.disturbance == .freelyMoving {
                // turns every wave semi-slowly into a triangular shape, 
                //  according to the stickyoutnessReq for energy loss
                // Overall, a weird effect that shouldn't necessarily be in here.
                let triangularize = true
                if triangularize {
                    let stickyoutness = 
                        abs(column.position.y - (column.left?.position.y ?? column.position.y)) + 
                        abs(column.position.y - (column.right?.position.y ?? column.position.y)) 
                    let stickyoutnessReq = 3.0
                    if stickyoutness > stickyoutnessReq {
                        // some columns shoot up too much, just have it be slowed down if that happens.
                        let energyRatioLost = 0.0001 * stickyoutness
                        let lostSpeed = column.verticalVelocity * energyRatioLost

                        return { column.verticalVelocity -= lostSpeed }
                    }
                }
            }

            // blah long comments.
            do {
            /*
            https://theconversation.com/curious-kids-how-do-ripples-form-and-why-do-they-spread-out-across-the-water-120308
            Water is also made of molecules. But during a ripple, the water molecules don’t move away from the rock, as you might expect. 
            They actually move up and down. When they move up, they drag the other molecules next to them up – 
            then they move down, dragging the molecules next to them down too.
            */

            // with the above theory, let's try to use it
            // How does the differences in height and verticalVelocities affect verticalVelocity?
            //  If it works like a spring, we only care about the difference in height.
            // When do we use the differences in height to affect verticalVelocity?
            //  Ramblings: We want to still converse the existing line fit strategy for the peak wave. 
            //  Therefore, we want the peak wave to be unaffected.
            //  Ans: When the water column we want to change the verticalVelocity of goes underwater 
            //   (the difference will be zero, given that we make sure to update waterColumns AFTER we calculate their next states)
            // IMPORTANT BEHAVIOR: How to move waves in a propagating fashion?
            //  Ramblings/Ans: Say a wave propagates to the right. How is the achievable?
            //   A wave say is moving upwards. It pulls waves from the right up, but it would also pull waves from the left up.
            //   How can this be? Well, say we have three sections, the left, the middle, and the right.
            //   The waves from the left should be falling, and the waves from the right rising perfectly cancels it all out
            //   Okay, so then the waves on the left has its speed killed, the waves in the middle keeps rising, 
            //    and the waves on the right are being pulled up slowly. This achieves the effect we are looking for.
            //   The width of the wave is based on how the pulling up algorithm behaves.
            // MORE NOTES
            //  The peak wave should not be at the edge, even if the edge is presumably exciting waves outwards from it.
            //  However, the should first try to produce natural waves before we try to make the edge spawn waves in a "nice" shape.

            // TODO reread this thing
            // Final question; does the aforementioned important behavior behavior match with our desire for peak wave to be unaffected?
            //  Ramblings: For a wave that is resting, a wave next to it exciting it can make the peak wave unaffected if the rest requirement
            //   is a function of the speed of the wave. We still need to achieve the wave propagation deletes its own affect behind it.
            //   To achieve this, we want to at some point kill columns like this 
            //    (look at the left column, the middle column is peaking, and the right column has not had much time to rise yet) .:_
            //   In that diagram, the left column has movement very similar to the middle column. Real life indicates that when 
            //    the left column hits the water, it loses all its verticalVelocity.
            //   This can be achieved how?
            //    Idea: The left column and the right column at some point will be moving in opposite directions at some point. 
            //    This sounds like turbulence, and probably kills verticalVelocity.
            //   To account for a variety of propagation times (which should be differences in periods of wave rise behavior), 
            //    we want to generalize turbulence as a concept.
            //   Let's say that yes, any time of moving in opposite direction = take difference and kill column by that.
            //   Except that's not right, since the instant two columns move in opposite directions, the one that is rebounding has ~= 0 velocity.
            //   Therefore, we actually take the difference of two columns moving in opposite directions where one column has pent up energy.
            //    corresponding to how far below verticalZero it has gotten to.
            //   NO, we always make a column rebound with energy based on the difference between the columns it is next to.
            //   But to do this, we either look at the column to the right and left, and have leader columns at the edge of peak waves,
            //    or we have a direction to a propagating wave (requires solving the interaction of two colliding waves from different directions).
            //    Having leader columns should be simpler, but the reduction of leader columns is a weird idea
            //    Once a column has the difference taken out of it, we kill the verticalVelocity. It is possible that the distance below 
            //     verticalZero still causes interesting interactions.
            //    We use the estimator for determining how the pent up energy works.
            //    Except that there can be a column that just is rebounding but the other column has a lot of verticalVelocity and 
            //     distance below verticalZero.
            //    This means we have to somehow add these factors together, try using a simpler algorithm instead of a curve fit one.
            //   Okay, do we apply this to one column at a time?
            //   Yes, that should work for every column to propagate the wave.
            //   Finally, does this not interfere with peak wave behavior?
            //   We apply this opposite direction concept to a wave that is falling. Therefore yeah, that should work for a resting columns situation.
            //  Ans: THAT is how we want the wave propagation function to operate.

            // SCREW THIS PROPAGATING WAVES AS A CONCEPT BELOW
            // x velocity is different than just verticalVelocity and height.
            // I'll try having just propagating horizontal waves outwards from disturbances.
            // The waves lose energy over time and by passing thru columns that have vertical velocity.

            // How do propagating horizontal waves affect verticalVelocity?
            //  The more verticalVelocity a wave has, the more horizontal waves add to the verticalVelocity, and the more x velocity is taken away.
            // How fast does x velocity propagate?
            //  Idea: Instantly, once or slightly less often per frame for ease of calculation
            //  Idea: 
            // How do waves lose x velocity?
            //  Idea: It slowly decays
            //  Idea: It instantly loses it after passing some x velocity on 
            }

            return {}
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

        var change = false
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
                    if let r = right {
                        _ = r
                        // print("changing something to atEdge \(r.position.x)")
                        change = true
                    }
                    ret.2 = .atEdge
                }
                if disturbNeighbors(c2, c1) {
                    if let l = left {
                        _ = l
                        // print("changing something to atEdge \(l.position.x)")
                        change = true
                    }
                    ret.0 = .atEdge
                }

                if !disturbNeighbors(c1, c2) && !disturbNeighbors(c2, c1) {
                    // print("tf????? \(c1.disturbance) \(disturbance) \(c2.disturbance)")
                }
            }

            ret.1 = .freelyMoving
        }
        if change {
            // print("return \(ret)")
        }

        return ret
    }

    func update(awareColumns: some Collection<WaterColumn>) -> (UInt, UpdateClosures) {
        let dip = position.y - verticalZero 
        let newDip = position.y + verticalVelocity - verticalZero
        // generally, make newDip have a bit of a buffer.

        let dipBuffer = -0.0

        let isNewDip = newDip >= dipBuffer && dip < dipBuffer
        func alterWavePosColor(updatePosAndColor: @escaping () -> () -> Void) -> (UInt, UpdateClosures) {
            // now let's try to have the concept of waves
            let waveAlter: (() -> () -> Void)? = if let wave = wave {
                { wave.update(isNewDip: isNewDip, column: self, awareColumns: awareColumns) }
                // nil
            } else {
                nil
            }
            return indexExprsAndMax(exprs: [
                waveAlter,
                updatePosAndColor,
            ])
        }

        // A crush disruption can only occur here.
        // When Underwater
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
        Raylib.drawRectangle(Int32(position.x), Int32(position.y), Int32(Self.WIDTH), Int32(bottom - position.y), color)
        Raylib.drawRectangleLines(Int32(position.x), Int32(position.y), Int32(Self.WIDTH), Int32(bottom - position.y), Color.yellow)
    }
}