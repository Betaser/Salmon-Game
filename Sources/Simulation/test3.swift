import Raylib

class Test3 : Test1 {
    // Only difference is spawning waves in both directions at the same time with a gap in between. Prepping for wave spawning

    override func reinit() {
        super.reinit()
        // But position waves to be perfectly still
        let gravity = WaterColumn.MASS * WaterColumn.GRAVITY
        let dip = gravity / WaterColumn.SPRING_FACTOR

        for column in water {
            column.position.y = WaterColumn.VERTICAL_ZERO - dip
            column.wave.height = column.position.y
        }
    }

    override func update() {
        if Raylib.isKeyPressed(.letterR) {
            reinit()
            return
        }

        if Raylib.isKeyPressed(.space) {
            let center = Int(Self.WATER_COLUMN_COUNT / 2)
            water[center - 3].wave.horzVel = -0.5
            water[center + 3].wave.horzVel = 0.5
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