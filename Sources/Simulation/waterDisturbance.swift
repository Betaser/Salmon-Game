import Foundation

class WaterDisturbance {
    var peakWave: DiscreteFunction
    let columnCount: Int
    var range: Range<Float64>

    static let VACUUM_STRENGTH = 0.50

    init(columnCount: Int) {
        self.columnCount = columnCount
        range = Float64(WaterColumn.WIDTH / 2)..<Float64(
            columnCount * WaterColumn.WIDTH + Int(WaterColumn.WIDTH / 2))
        peakWave = DiscreteFunction(stepSize: 0.0, xYFunction: { _ in 0.0 })
        // so that we can reference self.
        defer {
            peakWave = DiscreteFunction(
                stepSize: Float64(WaterColumn.WIDTH), 
                // Lame but most succinct take the function and decompose it strategy
                xYFunction: { [unowned self] in 
                    _ = self

                    let start = 10.0
                    let count = Double(columnCount)
                    let res = ((start < $0) && ($0 < start + count * Float64(WaterColumn.WIDTH))) ? 
                        100.0 * (1.0 - $0 / (count * Float64(WaterColumn.WIDTH))) : 
                        0.0
                    return res
                }
            )
        }
    }

    func crushColumns<T>(columns: T) where T: Collection, T.Element == WaterColumn, T.Index == Int {
        let columnHeights = peakWave.getOutputs(range: range)

        for (height, column) in zip(columnHeights, columns) {
            column.verticalVelocity += height * Self.VACUUM_STRENGTH
        }
    }
}