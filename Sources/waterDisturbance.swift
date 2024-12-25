import Foundation

// start with a parabola
struct DiscreteFunction {
    let stepSize: Float64
    let xYFunction: (Float64) -> Float64

    func getOutputs(range: Range<Float64>) -> [Float64] {
        var outputs: [Float64] = []
        var x = range.lowerBound
        while x < range.upperBound {
            outputs.append(xYFunction(x)) 
            x += stepSize
        }
        return outputs
    }
}

class WaterDisturbance {
    var peakWave: DiscreteFunction
    let columnCount: Int
    var range: Range<Float64>

    init(columnCount: Int) {
        self.columnCount = columnCount
        range = Float64(WaterColumn.WIDTH / 2)..<Float64(
            columnCount * WaterColumn.WIDTH + Int(WaterColumn.WIDTH / 2))
        peakWave = DiscreteFunction(stepSize: 0.0, xYFunction: { _ in 0.0 })
        // so that we can reference self.
        defer {
            peakWave = DiscreteFunction(
                stepSize: Float64(WaterColumn.WIDTH), 
                // upside down parabola
                xYFunction: { [unowned self] in 
                    let center = (range.upperBound - range.lowerBound) / 2
                    let normalizedX = ($0 - center) / ((range.upperBound - range.lowerBound) / 2)
                    return (WaterColumn.VERTICAL_ZERO - 100) * (1 - pow(normalizedX, 2))
                }
            )
        }
    }

    func crushColumns<T>(columns: T) where T: Collection, T.Element == WaterColumn, T.Index == Int {
        let columnHeights = peakWave.getOutputs(range: range)
        // print(columnHeights)
        for (height, column) in zip(columnHeights, columns) {
            // how do we get the peak height from an assumed verticalZero height and zero verticalVelocity?
            // for now, assume CRUSH_ENERGY_SAVED is 1.0
            // it actually works where crush 5 eventually == add 5 vel upwards
            // 1/2mv^2 = mgh

            // tried time based, doesn't work any better.
            let velocity = (2 * WaterColumn.GRAVITY * height).squareRoot()
            // column.crushedBy(amt: velocity)
            // if we start at vertical zero with no velocity, this is true
            // column.expectedCrushStartVelocity = column.verticalVelocity

            // but now, let's actually take into account CRUSH_ENERGY_SAVED

            // let _ = -1.228559 * pow(waterDrag.startingVelocity, 0.9833912)
            let crushVel = -1.228559 * pow(velocity, 0.9833912)
            column.expectedCrushStartVelocity = crushVel
            // SO WE CAN JUST SEE HORZ STUFF
            column.crushedBy(amt: -2)

            // BUT also, define how x velocities get set 
            // (because they are what truly cause vertical force resulting in waves.)
        }

        // make the columns edge columns
        assert(columns.count >= 2)
        columns.first!.disturbance = .atEdge
        columns.get(-1)!.disturbance = .atEdge

        let vacuumLedVel = columnHeights.reduce(0, { a, b in a + b })
        columns.first!.velocity.x += vacuumLedVel / 1000
        columns.get(-1)!.velocity.x += -vacuumLedVel / 1000

        // slices are efficient views
        // startIndex != 0 because it is a slice.
        for column in columns[columns.startIndex + 1..<columns.endIndex - 1] {
            column.disturbance = .beingDisturbed
        }
    }
}