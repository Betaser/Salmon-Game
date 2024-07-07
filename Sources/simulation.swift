// the only current state.
import Raylib

class Simulation {
    var water: [WaterColumn] = []
    var counter: Int32
    var simSpeed = 1.0
    var leftoverSpeed = 0.0
    var isCrush = false
    var isSuspend = false

    init() {
        counter = 0
        reinit()
    }

    func reinit() {
        water.removeAll()
        counter = 0
        simSpeed = 1
        leftoverSpeed = 0.0
        isCrush = false
        isSuspend = false

        for i in 0..<1 {
            water.append(WaterColumn(position: Vector2(
                x: Float64(400 + WaterColumn.WIDTH * i), 
                y: WaterColumn.VERTICAL_ZERO)))
        }
    }

    func manageSimSpeed() {
        if Raylib.isKeyPressed(.letterD) {
            isCrush = true
        }
        if Raylib.isKeyPressed(.letterS) {
            isSuspend = true
        }

        if Raylib.isKeyDown(.left) {
            simSpeed -= 0.1
            counter = 0
        }
        if Raylib.isKeyDown(.right) {
            simSpeed += 0.1
            counter = 0
        }
        simSpeed = max(0, simSpeed)

        // just render the last simulation data
        var text: (String, Int32, Int32, Int32, Color)? = nil
        leftoverSpeed += (simSpeed.truncatingRemainder(dividingBy: 1)) 
        if leftoverSpeed >= 1 {
            leftoverSpeed -= 1

            text = manageWater(isCrush: isCrush, isSuspend: isSuspend)
            isCrush = false
            isSuspend = false
        }
        for _ in 0..<Int(simSpeed) {
            text = manageWater(isCrush: isCrush, isSuspend: isSuspend)
            isCrush = false
            isSuspend = false
        }

        if let text = text {
            Raylib.drawText(text.0, text.1, text.2, text.3, text.4)
        }
    }

    func manageWater(isCrush: Bool, isSuspend: Bool) -> (String, Int32, Int32, Int32, Color) {
        var text = ""
        for column in water {
            // Crush disturbance
            if isCrush {
                column.crushedBy(amt: 5)
            }
            // Suspend disturbance
            if isSuspend {
                column.position.y -= 100
            }
            column.update()

            text += "Vertical velocity: \(String(format: "%.4f", column.verticalVelocity))\n"
        }
        return (text, screenWidth - 300, 350, 20, Color.darkGreen)
    }
    
    func update() {
        if Raylib.isKeyPressed(.letterR) {
            reinit()
            return
        }

        manageSimSpeed()

        for column in water {
            column.render()
        }

        // render verticalZero.
        let verticalZeroBuf: Int32 = 100
        Raylib.drawRectangle(verticalZeroBuf, Int32(WaterColumn.VERTICAL_ZERO), screenWidth - 2 * verticalZeroBuf, 5, Color.red)

        counter += 1
        Raylib.drawText("simulation counter: \(counter)", 100, 100, 20, Color.darkGreen)
        Raylib.drawText("Simulation Speed: \(String(format: "%.4f", simSpeed))", screenWidth - 300, 100, 20, Color.darkGreen)
        // controls
        Raylib.drawText("Controls: \nR to reset simulation\nD to crush water\nS to suspend water", 100, 150, 20, Color.darkGreen)
    }
}