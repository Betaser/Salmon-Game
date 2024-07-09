// the only current state.
import Raylib
import Foundation

class Simulation {
    struct Inputs {
        var isCrush: Bool
        var isSuspend: Bool
        var ranWaterDragSim: Bool
        mutating func shutoffAll() {
            isCrush = false
            isSuspend = false
            ranWaterDragSim = false
        }
        func anyEnabled() -> Bool {
            return isCrush || isSuspend || ranWaterDragSim
        }
    }

    static let waterColumnCount = 13
    var water: [WaterColumn] = []
    var counter: Int32
    var simSpeed = 0.0
    var leftoverSpeed = 0.0
    var inputs: Inputs = Inputs(isCrush: false, isSuspend: false, ranWaterDragSim: false)
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
        if Raylib.isKeyDown(.letterW) {
            inputs.ranWaterDragSim = true
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
            waterDragSim(start: inputs.ranWaterDragSim)
            inputs.shutoffAll()
        }
        for _ in 0..<Int(simSpeed) {
            text = manageWater(isCrush: inputs.isCrush, isSuspend: inputs.isSuspend)
            waterDragSim(start: inputs.ranWaterDragSim)
            inputs.shutoffAll()
        }

        if let text = text {
            Raylib.drawText(text.0, text.1, text.2, text.3, text.4)
        }
    }

    let ACCEL = -0.06
    let DRAG_FACTOR = /*0.95*/ 0.99
    struct WaterDrag {
        var column = WaterColumn(position: Vector2(x: 50, y: WaterColumn.VERTICAL_ZERO))
        enum State {
            case starting
            case running
            case done
        }
        var state = State.done
        var done = true
        var frameCount = 0
        var apexFrameCount = -1
        var preApexFC = -1
        var startingVelocity = -1.0
        var endingVelocity = -1.0
        var estimateEndingVelocity = -1.0
    }
    var waterDrag = WaterDrag()
    func waterDragSim(start: Bool) {
        if start {
            waterDrag.column.verticalVelocity += 4.0 / 30
            waterDrag.state = .starting
            waterDrag.apexFrameCount = -1
            waterDrag.preApexFC = -1
            waterDrag.frameCount = 0
            waterDrag.startingVelocity = -1
            waterDrag.endingVelocity = -1

            // try to estimate the ending velocity, but see below it's difficult
            return
        }
        if waterDrag.state == .done {
            return
        }
       
        if waterDrag.startingVelocity == -1 {
            waterDrag.startingVelocity = waterDrag.column.verticalVelocity
            waterDrag.estimateEndingVelocity = -5.918149 + 5.680574 * exp(0.1427285 * -waterDrag.startingVelocity)
        }

        waterDrag.frameCount += 1

        if waterDrag.column.verticalVelocity > 0 && waterDrag.column.verticalVelocity + ACCEL < 0 {
            waterDrag.preApexFC = waterDrag.frameCount
        }

        waterDrag.column.verticalVelocity += ACCEL
        waterDrag.column.verticalVelocity *= DRAG_FACTOR
        waterDrag.column.position.y += waterDrag.column.verticalVelocity
        if waterDrag.column.position.y < waterDrag.column.verticalZero {
            // https://python-fiddle.com/examples/matplotlib?checkpoint=1720513149 + mycurvefit + google sheets formatting
            // very accurate, I'm impressed
            // BUT, we want to pass in the correct time into this function, which we do not know about
            // waterDrag.estimateEndingVelocity = -1.14 + (1.14 + waterDrag.startingVelocity) * exp(-0.05129329 * Double(waterDrag.frameCount))
            // This function works quite quite well. I would say we should apply this same idea and strategy to the actual simulation.

            print("with starting velocity and \(waterDrag.startingVelocity) frame count of \(waterDrag.frameCount), \(waterDrag.estimateEndingVelocity)")
            waterDrag.state = .done
            waterDrag.endingVelocity = waterDrag.column.verticalVelocity
            print("velocity = \(waterDrag.column.verticalVelocity)")
            waterDrag.column.reinit()
            return
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
        // debugging
        waterDrag.column.render()
        Raylib.drawText("Water Drag frames:\nframe \(waterDrag.frameCount)\npreApexFrame \(waterDrag.preApexFC)\nWater Drag starting velocity: \(waterDrag.startingVelocity)\nWater Drag ending velocity: \(waterDrag.endingVelocity)\nWater Drag estimated ending velocity: \(waterDrag.estimateEndingVelocity)", 100, screenHeight - 300, 20, Color.magenta)

        counter += 1
        Raylib.drawText("Simulation counter: \(counter)", 100, 100, 20, Color.darkGreen)
        Raylib.drawText("Simulation Speed: \(String(format: "%.4f", simSpeed))", screenWidth - 300, 100, 20, Color.darkGreen)
        // controls
        Raylib.drawText("Controls: \nR to reset simulation\nD to crush water\nS to suspend water\nW to test water drag", 100, 150, 20, Color.darkGreen)
    }
}