import Foundation
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
    var restitution: Float64;

    deinit { refCount -= 1 }

    init(position: Vector2) {
        refCount += 1
        self.position = position
        verticalZero = 0
        originalPosition = position.clone()
        color = Color.blue
        bottom = 0
        expectedCrushStartVelocity = 0
        restitution = 0.9;
        wave = Wave() 
        reinit()
    }

    func reinit() {
        position = originalPosition.clone()
        verticalVelocity = 0
        verticalZero = Self.VERTICAL_ZERO
        velocity.x = 0
        velocity.y = 0
        color = Color.blue
        bottom = position.y + Float64(Self.HEIGHT)
        expectedCrushStartVelocity = 0
        disturbance = .freelyMoving
    }

    func clone() -> WaterColumn {
        var ret = WaterColumn(position: position)
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

            if false {
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
            }

            // blah long comments. Contains the massive brainstorming rambling paragraph
            if true || isNewDip {
                func inelasticCollision(v: Float64, colliderV: Float64) -> Float64 {
                    return (1 - column.restitution) / 2.0 * v + (1 + column.restitution) / 2.0 * colliderV
                }

                // deal with columns who are next to nothing.
                let leftV = column.left?.velocity.x ?? 0
                let rightV = column.right?.velocity.x ?? 0
                // let leftV = data.0
                // let rightV = data.1

                let currV = column.velocity.x
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
                let leftUsed = leftV * currV > 0 || leftV - currV > 0
                let rightUsed = rightV * currV > 0 || rightV - currV < 0
                let neighboringV = (leftUsed ? leftV : 0) + (rightUsed ? rightV : 0)

                let collidedVel = inelasticCollision(v: currV, colliderV: neighboringV)
                // the two expr below are different.
                // let otherVel = currV + neighboringV - collidedVel
                // let otherVel = inelasticCollision(v: neighboringV, colliderV: currV)
                // this is not symmetric either:
                // let otherVel = leftV + rightV
                let otherVel = currV

                // But, we also need to calculate the inelastic collision results for the other columns, 
                // otherwise we just gain speed over time.
                let xVel = column.velocity.x
                let verticalVel = column.verticalVelocity
                var lv = column.left?.velocity.x ?? 0
                var rv = column.right?.velocity.x ?? 0
                // so if we have lv, rv = -3, 5, and otherVel = 2, then we should distribute them to be -1/3, 1/3
                let factor = otherVel / (abs(lv) + abs(rv))

                return {
                    if collidedVel != 0 {
                        // print(collidedVel)
                    }
                    let velChange = abs(collidedVel) - abs(xVel) 
                    // column.verticalVelocity *= 1.05
                    column.velocity.x = collidedVel * 0.2

                    // column.verticalVelocity = 2 / (abs(column.velocity.x) + 1)

                    if (velChange < 0) {
                        // print("change by \(velChange)")
                        // pow is not symmetrical maybe?
                        // column.verticalVelocity = verticalVel + -pow(-velChange, 0.4) * 0.5
                        column.verticalVelocity = verticalVel + velChange * 0.5
                        // column.verticalVelocity = 2 / -(abs(column.velocity.x) + 1)
                    }

                    return {
                        // So the code below is symmetrical, just for testing purposes.
                        /*
                        column.left?.velocity.x += -9
                        column.right?.velocity.x += 9
                        */

                        // the first two below things are not symmetric, but the else case works.

                        // setting only left or only right in these bools aren't symmetric, but they should be.

                        if !leftUsed || column.left == nil {
                            if false && abs(velChange) > 10 {
                            print("\(collidedVel) \(xVel)")
                            print(column.verticalVelocity)
                            }
                            // it is not symmetric to set x to any value, dunno why.
                            // this zeroes things out usually.
                            // column.right?.velocity.x += otherVel
                            // column.right?.velocity.x /= 999
                            // column.right?.velocity.x -= 0.2;
                            // below works for using f(abs(vel.x)) instead of collisions.
                            // this is symmetric
                            // column.right?.verticalVelocity += 1
                        }
                        if !rightUsed || column.right == nil {
                            // column.left?.velocity.x += otherVel
                            // column.left?.velocity.x /= 999
                            // column.left?.velocity.x += 0.2;
                            // column.left?.verticalVelocity += 1
                        }
                        // if column.left != nil && column.right != nil {
                        // not symmetric in combination with the stuff above, even when the stuff above is by itself symmetric
                        if !((!leftUsed || column.left == nil) || (!rightUsed || column.right == nil)) {
                            // column.left?.velocity.x = lv + -9
                            // column.right?.velocity.x = rv + 9
                            // clearly otherVel and factor aren't calculated right; they need to be abs or else its not symmetric.
                            column.left?.velocity.x = lv == 0 ? abs(otherVel) / 2 : lv * abs(factor)
                            column.right?.velocity.x = rv == 0 ? -abs(otherVel) / 2 : rv * abs(factor)
                            // print(column.left?.velocity.x)
                        }
                    }
                }
            /* Look at paper diagram for more info.
            Key points:
            1. Apply 1D inelastic collision physics with a defined resitution coefficient
            2. Treat the v1 and v2 inputs into the equation as follows:
                i. v1 x velocity of the current column
                ii. v2 x velocity of the sum of the neighboring columns, with rules on "pushing" and "colliding"
            3. After finding the final x velocity, if it is less than the prev frame's, turn that into vertical velocity

            Screw the stuff below
            */

            /*
            Latest concerns:
            I assumed that water columns collide into each other equally into a middle column, but this need not be the case. 
            What about two water columns next to each other than get sent into each other?
            h:  2  0     0  2
            hv: >> >>> <<< <<
                    A   B
            Call the two central columns A and B.
            A and B have relative velocities of the following.
            For A, 2 - 3 = -1 (1 to the left) on its left, and -3 - 3 = -6 (6 to the left) on its right. 
            Take the difference and absolute value it and we get |-1 - -6| = 5. But, we should instead just do |2 - -3| = 5.
            For B, we do |-3 - 2| = 5.
            We conclude that we take the magnitude of their energy and set vertical velocity to a function of that.
            On the other hand, the resulting x velocity of the water column should be the sum plus the current x velocity.
            For A: 2 + -3 + 3 = 2
            For B: 3 + -2 - 3 = -2
            Therefore, we get
            h:  2 f(5)  f(5) 2
            hv: >> >>    << <<
                    A    B
            But, that assumed the columns surrounding A and B did not change. We expect that they lost some energy.
            Therefore there can be a simple energy decay for the water x velocity. 
            I think the higher the water is, the more percentage of x velocity it loses. 

            However, the more important example to look at is this:
            0 >>> > <   ->    0  > >>> <
            a  b  c d         a  b  c  d
            Intuitively, we can see that b transferred most of its x velocity into c. c gained b + d = 2 velocity.
            b would be calculated as 0 + 1 + 3 = 4 velocity, but this makes no sense. We reject that idea.
            We therefore accept the outcome of b imparting its energy into c.
            To achieve this, we can go from left to right or right to left, and make sure we get the same result.

            Left to right case:
            We first come across the column b. It has a higher velocity than that to its left and right.
            Here, apply elastic headon collision formula.
            Then, vb = 3, vc = -1
                  v'b = vc, v'c = vb (literally just a swap)
            Ex:
            0 >>> < <   ->    0  < >>> <
            a  b  c d         a  b  c  d
            We notice b 

            NOTE however, these interactions should only kick in after the first wave from the initial disturbance.
            */

            /*
            I honestly kind of forget what I was saying, though I'm sure when I find my diagrams I'll remember.
            However, let's just try deriving a new strategy, why not.
            So, we like the idea that the impulse of some imaginary object pushing water down causes everything to follow.
            Okay, well I believe that in real life, the water will be forced to run into itself around the object as the object sinks far enough. And we remember that we desire for the first peak to be a simple spring-based and gravity-affected trajectory. 
            After such behavior, let's consider what occurs after this peak. So, we do have to define when weird other interactions besides springs and gravity matter. (TODO)
            But suppose we have figured out how to define the instances in which other interactions affect trajectories.
            For simplicity's sake, perhaps let's imagine an object that is causing the splash as being a super thin disk. I mean, for a salmon's tail this is reasonable. 
            Then we can know that the sudden vacuum created by the slap of the tail accelerating water downards should cause water that was the to left and right of the water displaced to flow inwards. What happens then?
            Well we know that the first column is about as wide at the base as the object that caused such a thing to occur. Subsequent peaks should be thinner, according to real life.
            Then to mimic this, as water crashes into itself side-on, it should probably yeet upwards. This is because it can't go downwards, and it is being compressed from the sides. 
            Suppose we take the first instance of a little bit of water crashing into itself. We can say it crashes into itself within one location, so one column gets excited.
            The excited column yeets upwards. On the next frame, the column gets compressed on the left and right again, but less so, since energy was lost. 
            The one column gets compressed again even more, and the left and right columns get compressed themselves, so they should yeet up. But how is this possible to calculate? 
            Exhibit A:
            Columns represented under the ________ representing vertical zero.
            Height represented with h: row and numbers on top of each column.
            horizontal velocity with >>>> <<<<

            h:  +0 +1 +3 +1 +0
            hv: >>>        <<<
            ____-2 -1 +0 +1 +2____

            h:  +0 +2 +5 +2 +0
            hv: >>          <<
            ____-2 -1 +0 +1 +2____

            Of course this example is of symmetric, odd-numbered column disturbance, which is the design which I am targeting.
            Note that the relative velocity of the peak column is massive from the right and left. It goes from +0 +0 +0 (x vel of left column, x vel of it, x vel of right column) to +5 +0 +5 for example.
            For the columns next to it, take the left column for example. It goes from +0 +3 +0 to +3 +3 +0 as the vacuum pulls the columns that are on the edge of the disturbance move.
            (Here, note that even though the edge of the disturbance moves inwards, we follow the edge column, so it goes from +7 to +3 velocity.) (Also note that there has to be some intermediate column "created" in a sense, since the edge moves but no gap is created.)
            Well, eventually it collides with the edge coming from the other side. This frame looks like this:
            +3 +3 |collision here!| -3 -3
            On the next frame, it turns into 
            +3 +1 |collision here!| -1 -3
            The center column still has no velocity, but we can see that the columns which just gave the center column energy now have less x velocity. They now have relative velocity, and are being slightly compressed.
            Therefore, they should get some excitement upwards. And the process will lead to some kind of bell curve I have to guess.
            
            Okay, then we should return to asking when this comes into play. And I think the answer is when water is below verticalZero, but upon the fish tail slapping originally, we pretend some length of an object is passing through and stops this interaction from occuring.
            */

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
        Raylib.drawRectangle(Int32(position.x), Int32(position.y), Int32(Self.WIDTH), Int32(bottom - position.y), color)
        Raylib.drawRectangleLines(Int32(position.x), Int32(position.y), Int32(Self.WIDTH), Int32(bottom - position.y), Color.yellow)
    }
}