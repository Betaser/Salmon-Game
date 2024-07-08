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
    var range: Range<Float64>

    init(columnCount: Int) {
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
                    let normalizedX = ($0 - center) / (range.upperBound - range.lowerBound)
                    return (WaterColumn.VERTICAL_ZERO - 20) * (1 - pow(normalizedX, 2))
                }
            )
        }
    }

    func crushColumns(columns: [WaterColumn]) {
        let columnHeights = peakWave.getOutputs(range: range)
        for (height , column) in zip(columnHeights, columns) {
            // how do we get the peak height from an assumed verticalZero height and zero verticalVelocity?
            // for now, assume CRUSH_ENERGY_SAVED is 1.0
            // it actually works where crush 5 eventually == add 5 vel upwards
            // 1/2mv^2 = mgh

            // tried time based, doesn't work any better.
            let velocity = (2 * WaterColumn.GRAVITY * height).squareRoot()
            column.crushedBy(amt: velocity)
            column.expectedCrushStartVelocity = column.verticalVelocity
        }
    }
}