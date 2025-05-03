import Raylib
import Foundation

class Test2 : Test1 {
    static let WC_COUNT: Int32 = 3

    override func reinit() {
        water.removeAll()
        counter = 0
        simSpeed = 1.0
        leftoverSpeed = 0.0

        let WIDTH: Int32 = 100
        let horzWaterBuf: Int32 = (screenWidth - Int32(Self.WC_COUNT * WIDTH)) / 2

        let gravity = WaterColumn.MASS * WaterColumn.GRAVITY
        // when spring = gravity
        let dip = gravity / WaterColumn.SPRING_FACTOR

        for i in 0..<Self.WC_COUNT {
            let column = WaterColumn(
                position: Vec2(
                    x: Float64(horzWaterBuf) + Float64((WIDTH + 5) * i), 
                    y: WaterColumn.VERTICAL_ZERO - dip),
                waterColumnCount: Self.WC_COUNT,
                width: WIDTH)
            water.append(column)
        }

        // now set the left and right columns.
        for i in 1..<Int(Self.WC_COUNT - 1) {
            water[i].left = water[i - 1]
            water[i].right = water[i + 1] 
        }

        water[0].right = water[1]
        water[water.count - 1].left = water[water.count - 2]

        // set the edge columns to atEdge.
        frameByFrame = false
    }

    deinit {
        // must deinit water columns' cyclical references.
        for column in water {
            column.left = nil
            column.right = nil
        }
    }

}