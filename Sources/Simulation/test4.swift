import Raylib

class Test4 : Test1 {
    override func reinit() {
        water.removeAll()
        counter = 0
        simSpeed = 1.0
        leftoverSpeed = 0.0

        let horzWaterBuf: Int32 = (screenWidth - Int32(Self.WATER_COLUMN_COUNT * WaterColumn.WIDTH)) / 2

        let gravity = WaterColumn.MASS * WaterColumn.GRAVITY
        let dip = gravity / WaterColumn.SPRING_FACTOR

        // Set the column to the y position such that it does not oscillate
        for i in 0..<Self.WATER_COLUMN_COUNT {
            let column = WaterColumn(
                position: Vec2(
                    x: Float64(horzWaterBuf) + Float64(WaterColumn.WIDTH * i), 
                    y: WaterColumn.VERTICAL_ZERO - dip),
                waterColumnCount: Self.WATER_COLUMN_COUNT,
                width: WaterColumn.WIDTH)
            column.wave.height = column.position.y
            water.append(column)
        }

        // now set the left and right columns.
        for i in 1..<Int(Self.WATER_COLUMN_COUNT - 1) {
            water[i].left = water[i - 1]
            water[i].right = water[i + 1] 
        }

        water[0].right = water[1]
        water[water.count - 1].left = water[water.count - 2]

        frameByFrame = false
    }

    override func update() {
        if Raylib.isKeyPressed(.letterR) {
            reinit()
            return
        }
        
        if Raylib.isKeyPressed(.space) {
            let center = Int(Self.WATER_COLUMN_COUNT / 2)
            let halfWidth = 1
            water[center - halfWidth].wave.horzVel = -0.42
            water[center + halfWidth].wave.horzVel = -water[center - halfWidth].wave.horzVel

            // Create a vacuum in the central columns
            for column in water[center - halfWidth..<center + halfWidth + 1] {
                column.wave.vertVel -= 8.0
            }
        }

        // background of white to gray gradient top to bottom is nice
        let topColor = Color(r: 230, g: 230, b: 230, a: 255)
        let bottomColor = Color(r: 30, g: 30, b: 30, a: 255)
        Raylib.drawRectangleGradientV(0, 0, screenWidth, screenHeight, topColor, bottomColor)       
    
        // Render verticalZero at that amount above bottom.
        do {
            let buf: Int32 = 100
            let height: Int32 = 6
            Raylib.drawRectangle(
                buf, 
                Self.COLUMN_BOTTOM - Int32(WaterColumn.V_SCALE * WaterColumn.VERTICAL_ZERO) - height / 2, 
                screenWidth - 2 * buf, 
                height, 
                Color.red)
        }

        manageSimSpeed()

        for column in water {
            column.render(bottom: Self.COLUMN_BOTTOM, vScale: WaterColumn.V_SCALE)
        }
    }    
}