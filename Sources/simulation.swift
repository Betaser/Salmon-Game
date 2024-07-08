// the only current state.
import Raylib

class Simulation {
    struct Inputs {
        var isCrush: Bool
        var isSuspend: Bool
        mutating func shutoffAll() {
            isCrush = false
            isSuspend = false
        }
        func anyEnabled() -> Bool {
            return isCrush || isSuspend
        }
    }

    static let waterColumnCount = 13
    var water: [WaterColumn] = []
    var counter: Int32
    var simSpeed = 0.0
    var leftoverSpeed = 0.0
    var inputs: Inputs = Inputs(isCrush: false, isSuspend: false)
    let disturbance = WaterDisturbance(columnCount: waterColumnCount)

    init() {
        counter = 0
        reinit()
    }

    func reinit() {
        water.removeAll()
        counter = 0
        simSpeed = 0
        leftoverSpeed = 0.0
        inputs.shutoffAll()

        let horzWaterBuf: Int32 = (screenWidth - Int32(Simulation.waterColumnCount * WaterColumn.WIDTH)) / 2

        for i in 0..<Simulation.waterColumnCount {
            water.append(WaterColumn(position: Vector2(
                x: Float64(horzWaterBuf) + Float64(WaterColumn.WIDTH * i), 
                y: WaterColumn.VERTICAL_ZERO)))
        }
    }

    func manageSimSpeed() {
        if Raylib.isKeyPressed(.letterD) {
            inputs.isCrush = true
        }
        if Raylib.isKeyPressed(.letterS) {
            inputs.isSuspend = true
        }

        if inputs.anyEnabled() {
            simSpeed = 1
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

            text = manageWater(isCrush: inputs.isCrush, isSuspend: inputs.isSuspend)
            inputs.shutoffAll()
        }
        for _ in 0..<Int(simSpeed) {
            text = manageWater(isCrush: inputs.isCrush, isSuspend: inputs.isSuspend)
            inputs.shutoffAll()
        }

        if let text = text {
            Raylib.drawText(text.0, text.1, text.2, text.3, text.4)
        }
    }

    func manageWater(isCrush: Bool, isSuspend: Bool) -> (String, Int32, Int32, Int32, Color) {
        // Crush disturbance
        if isCrush {
            disturbance.crushColumns(columns: water)
        }

        var text = ""
        for column in water {
            // Suspend disturbance
            if isSuspend {
                column.position.y -= 100
            }
            column.update()

            text += "Vertical velocity: \(String(format: "%.4f", column.verticalVelocity))\n"
        }
        return (text, screenWidth - 300, 175, 20, Color.darkGreen)
    }
    
    func update() {
        if Raylib.isKeyPressed(.letterR) {
            reinit()
            return
        }

        // render verticalZero.
        let verticalZeroBuf: Int32 = 100
        Raylib.drawRectangle(verticalZeroBuf, Int32(WaterColumn.VERTICAL_ZERO), screenWidth - 2 * verticalZeroBuf, 5, Color.red)
        Raylib.drawRectangle(verticalZeroBuf, 20, screenWidth - 2 * verticalZeroBuf, 5, Color.orange)

        manageSimSpeed()

        for column in water {
            column.render()
        }

        counter += 1
        Raylib.drawText("simulation counter: \(counter)", 100, 100, 20, Color.darkGreen)
        Raylib.drawText("Simulation Speed: \(String(format: "%.4f", simSpeed))", screenWidth - 300, 100, 20, Color.darkGreen)
        // controls
        Raylib.drawText("Controls: \nR to reset simulation\nD to crush water\nS to suspend water", 100, 150, 20, Color.darkGreen)
    }
}