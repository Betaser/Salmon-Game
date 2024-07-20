import Raylib
// position at top left
// could consider the center as the position

class WaterColumn {
    static let MASS = 4.5
    static let SPRING_FACTOR = 0.045
    static let VERTICAL_ZERO = 300.0
    static let GRAVITY = 0.045
    static let WIDTH = 20
    static let HEIGHT = 200
    static let CRUSH_ENERGY_SAVED = 0.99

    unowned var left: WaterColumn? = nil 
    unowned var right: WaterColumn? = nil 

    enum Disturbance {
        case freelyMoving
        case atEdge
        case beingDisturbed
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
    var verticalVelocity: Float64
    var expectedCrushStartVelocity: Float64
    var crushVelocity: Float64
    private var bottom: Float64
    private (set) var verticalZero: Float64

    deinit { refCount -= 1 }

    init(position: Vector2) {
        refCount += 1
        self.position = position
        verticalVelocity = 0
        verticalZero = 0
        originalPosition = position.clone()
        color = Color.blue
        bottom = 0
        expectedCrushStartVelocity = 0
        crushVelocity = 0
        reinit()
    }

    func reinit() {
        position = originalPosition.clone()
        verticalVelocity = 0
        verticalZero = Self.VERTICAL_ZERO
        color = Color.blue
        bottom = position.y + Float64(Self.HEIGHT)
        expectedCrushStartVelocity = 0
        crushVelocity = 0
        disturbance = .freelyMoving
    }

    func updateWave() {
        if left == nil {
            // left wall
        } else if right == nil {
            // right wall
        }

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

    func crushedBy(amt: Float64) {
        // verticalVelocity += amt
        crushVelocity += amt
    }

    func update() {
        let dip = position.y - verticalZero 
        let newDip = position.y + verticalVelocity - verticalZero
        
        // Basic way to alter disturbance
        if abs(verticalVelocity + crushVelocity) + abs(dip) < 2.0 {
            disturbance = .freelyMoving
            // Assume that either the left or right has columns to disturb.
            // Otherwise, if the column is the last .beingDisturbed, it eventually dies
            if let c1 = left, let c2 = right {
                func disturbNeighbors(_ n1: WaterColumn, _ n2: WaterColumn) {
                    if n1.disturbance == .freelyMoving && n2.disturbance == .beingDisturbed {
                        n2.disturbance = .atEdge
                    }
                }
                disturbNeighbors(c1, c2)
                disturbNeighbors(c2, c1)
            }
        }

        // A crush disruption can only occur here.
        // When Underwater
        if newDip >= 0 {
            // as the water passes past vertical zero from above, reset position to vertical zero and try to set the proper velocity
            // basically we do noise correction which is funky.
            if dip < 0 {
                /*
                position.y = verticalZero
                let velocityRatio = verticalVelocity / expectedCrushStartVelocity
                if abs(velocityRatio - 1) < 0.1 {
                    verticalVelocity = expectedCrushStartVelocity
                } else {
                    print("Inaccurate, is \(verticalVelocity) expected \(expectedCrushStartVelocity)")
                }
                */

                // maybe the bigger velocity is, the more it is made smaller? That is, a function that is more harsh towards large values?
                verticalVelocity *= 0.9
            }

            verticalVelocity += crushVelocity
            crushVelocity = 0
            // A fraction of dip.
            let springForce = -Self.SPRING_FACTOR * dip
            let totalForce = springForce + Self.MASS * Self.GRAVITY

            verticalVelocity += totalForce / Self.MASS
            verticalVelocity *= Self.CRUSH_ENERGY_SAVED

            position.y += verticalVelocity
            
            // being crushed
            // invert the color
            let clr = disturbanceColors[disturbance]!
            color = Color(
                r: UInt8(255 * 0.3 + Float64(clr.r) * 0.7),
                g: UInt8(255 * 0.3 + Float64(clr.g) * 0.7),
                b: UInt8(255 * 0.3 + Float64(clr.b) * 0.7),
                a: clr.a)

            return
        }

        verticalVelocity += Self.GRAVITY
        verticalVelocity += crushVelocity
        crushVelocity = 0

        // now let's try to have the concept of waves
        updateWave()

        position.y += verticalVelocity

        // in the air
        color = disturbanceColors[disturbance]!
    }

    func render() {
        Raylib.drawRectangle(Int32(position.x), Int32(position.y), Int32(Self.WIDTH), Int32(bottom - position.y), color)
        Raylib.drawRectangleLines(Int32(position.x), Int32(position.y), Int32(Self.WIDTH), Int32(bottom - position.y), Color.yellow)
    }
}