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

    // static let waterColumnCount = 29
    // static let disturbanceCount = 13
    static let waterColumnCount = 19 * 6
    static let disturbanceCount = 5 * 6
    var water: [WaterColumn] = []
    var counter: Int32
    static var DEBUG_COUNTER: Int32 = 0
    var simSpeed = 0.0
    var leftoverSpeed = 0.0
    var inputs: Inputs = Inputs(isCrush: false, isSuspend: false, ranWaterDragSim: false)
    let disturbance = WaterDisturbance(columnCount: disturbanceCount)

    var frameByFrame = false
    var screenshot = Texture()
    var image = Image()
    var edgeInfo = ""
    var doScreenshotStuff = true
    var screenshotDelay = 1

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

        let horzWaterBuf: Int32 = (screenWidth - Int32(Self.waterColumnCount * WaterColumn.WIDTH)) / 2

        for i in 0..<Self.waterColumnCount {
            let column = WaterColumn(position: Vector2(
                x: Float64(horzWaterBuf) + Float64(WaterColumn.WIDTH * i), 
                y: WaterColumn.VERTICAL_ZERO))
            water.append(column)
        }

        // now set the left and right columns.
        for i in 1..<Self.waterColumnCount - 1 {
            water[i].left = water[i - 1]
            water[i].right = water[i + 1] 
        }
        
        water[0].right = water[1]
        water[water.count - 1].left = water[water.count - 2]

        // set the edge columns to atEdge.
        let halfOffset = (Self.waterColumnCount - Self.disturbanceCount) / 2
        water[halfOffset].disturbance = .atEdge
        water[Self.waterColumnCount - halfOffset - 1].disturbance = .atEdge
        frameByFrame = false
    }

    deinit {
        // must deinit water columns' cyclical references.
        for column in water {
            column.left = nil
            column.right = nil
            column.wave = nil
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

        if inputs.anyEnabled() && simSpeed == 0 {
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

    let ACCEL = -0.06
    let DRAG_FACTOR = /*0.95*/ 0.99
    // static var fuckYou = false

    var lastEdgeVel = 0.0
    func manageWater(isCrush: Bool, isSuspend: Bool) -> (String, Int32, Int32, Int32, Color) {
        // Crush disturbance
        if isCrush {
            let halfOffset = (Self.waterColumnCount - disturbance.columnCount) / 2
            let disturbedSlice = water[halfOffset..<Self.waterColumnCount - halfOffset]
            disturbance.crushColumns(columns: disturbedSlice)
        }

        // update water loop
        // do first, because disturbance setting requires a proper initialization of crushing.

        var waveData: [(Float64, Float64)] = []
        for col in water {
            waveData.append((col.left?.horzVelocity ?? 0, col.right?.horzVelocity ?? 0))
        }
                // let leftV = column.left?.horzVelocity ?? 0
                // let rightV = column.right?.horzVelocity ?? 0
        do {
            var allClosures: [UpdateClosures] = []
            var maxIndices: [UInt] = []

            for (i, col) in water.enumerated() {
                let (maxIndex, closures) = col.update(data: waveData[i], awareColumns: water)
                maxIndices.append(maxIndex)
                if closures.count > 0 {
                    allClosures.append(closures) 
                }
            }

            var closuresLeftAts: [Int : Int] = [:]
            for i in 0..<allClosures.count {
                closuresLeftAts[i] = 0
            }

            var closureI: UInt = 0
            while closuresLeftAts.count > 0 {
                var iter = closuresLeftAts.makeIterator()
                func loop() {
                    if let (allClosuresI, dist) = iter.next() {
                        // decrement dist
                        closuresLeftAts[allClosuresI] = closuresLeftAts[allClosuresI].unsafelyUnwrapped - 1

                        if dist > 0 {
                            loop()
                        }

                        let closures = allClosures[allClosuresI]
                        var possibleClosure = {}

                        if let closure = closures[closureI] {
                            possibleClosure = closure()
                        } else if closureI >= maxIndices[allClosuresI] {
                            closuresLeftAts.remove(at: closuresLeftAts.index(forKey: allClosuresI).unsafelyUnwrapped)
                        }

                        loop()
                        possibleClosure()
                    } else {
                        return
                    }
                }
                loop()

                closureI += 1
            }
        }

        // set water disturbance values
        var disturbances: [WaterColumn.Disturbance?] = Array(repeating: nil, count: water.count)
        do {
            var alterNum = 0
            var toPrint: [String] = []
            for i in 0..<water.count {
                let column = water[i]
                let dip = column.position.y - column.verticalZero
                let disturbed = column.alterDisturbance(dip: dip)
                toPrint.append("#\(i) \(column.disturbance.toString())")

                if let l = disturbed.0, let r = disturbed.2 {
                    switch (water[i - 1].disturbance, column.disturbance, water[i + 1].disturbance) {
                        case (.freelyMoving, .atEdge, .beingDisturbed), (.beingDisturbed, .atEdge, .freelyMoving): do {
                            toPrint.append("activated on #\(i) \(column.disturbance.toString())")
                            toPrint.append("\n\nthe cuttoff is \(abs(column.verticalVelocity) + abs(dip) < 4.0)\n\n")
                            toPrint.append("\nspecifically, \(abs(column.verticalVelocity)) + \(abs(dip))\n")
                            toPrint.append("the return values are \((l, disturbed.1, r))")
                            alterNum += 1
                            disturbances[i - 1] = l
                            disturbances[i] = disturbed.1
                            disturbances[i + 1] = r
                            break
                        }
                        default: do {
                        }
                    }
                }
            }

            for i in 0..<water.count {
                let disturbance = disturbances[i]
                if let d = disturbance {
                    water[i].disturbance = d        
                }
            }
        }


        var text = ""
        // Too many columns = render only 13 of them I guess?
        let N = 13
        let halfish = Int((water.count - N) / 2)
        for (i, column) in water[halfish..<water.count - halfish].enumerated() {
            // text += "#\(halfish + i) Vertical velocity: \(String(format: "%.4f", column.verticalVelocity))\n"
            text += "#\(halfish + i) x vel: \(String(format: "%.4f", column.horzVelocity))\n"
        }
        return (text, screenWidth - 300, 175, 20, Color.darkGreen)
    }
    
    func update() {
        doScreenshotStuff = true
        if Raylib.isKeyPressed(.letterT) {
            frameByFrame = !frameByFrame
        }

        // frameByFrame = Raylib.isKeyDown(.letterT)
        if Raylib.isKeyPressed(.letterR) {
            reinit()
            return
        }

        if Raylib.isKeyPressed(.space) {
            WaterColumn.waveCollisionsEnabled = !WaterColumn.waveCollisionsEnabled
        }

        if frameByFrame {
            defer {
                Raylib.drawText("Frame by frame mode on", 100, 70, 20, Color.darkBlue)
            }
            if !Raylib.isKeyPressed(.right) {
                Raylib.drawTexture(screenshot, 0, 0, Color.white)
                doScreenshotStuff = screenshotDelay == 1
                if screenshotDelay > 0 {
                    screenshotDelay -= 1
                }
                return
            }
            screenshotDelay = 1
            doScreenshotStuff = false
        }
        
        // background of white to gray gradient top to bottom is nice
        let topColor = Color(r: 230, g: 230, b: 230, a: 255)
        let bottomColor = Color(r: 30, g: 30, b: 30, a: 255)
        Raylib.drawRectangleGradientV(0, 0, screenWidth, screenHeight, topColor, bottomColor)

        // render verticalZero.
        let verticalZeroBuf: Int32 = 100
        Raylib.drawRectangle(verticalZeroBuf, Int32(WaterColumn.VERTICAL_ZERO), screenWidth - 2 * verticalZeroBuf, 5, Color.red)
        Raylib.drawRectangle(verticalZeroBuf, 100, screenWidth - 2 * verticalZeroBuf, 5, Color.orange)

        if frameByFrame {
            inputs.shutoffAll()
            if Raylib.isKeyDown(.letterD) {
                inputs.isCrush = true
            }

            let text: (String, Int32, Int32, Int32, Color) = manageWater(isCrush: inputs.isCrush, isSuspend: inputs.isSuspend)
            Raylib.drawText(text.0, text.1, text.2, text.3, text.4)
        } else {
            manageSimSpeed()
        }

        for column in water {
            column.render()
        }
        // debugging

        Self.DEBUG_COUNTER = counter
        counter += 1
        Raylib.drawText("Simulation counter: \(counter)", 100, 100, 20, Color.darkGreen)
        Raylib.drawText("Simulation Speed: \(String(format: "%.4f", simSpeed))", screenWidth - 300, 100, 20, Color.darkGreen)
        // controls
        Raylib.drawText("Controls: \nR to reset simulation\nD to crush water\nS to suspend water\nW to test water drag\nSpace to toggle wave physics\nT to toggle frame by frame analysis", 100, 150, 20, Color.darkGreen)

        // debugging atEdge stuff
        var atEdges: [WaterColumn] = []
        for column in water {
            if column.disturbance == .atEdge {
                atEdges.append(column)
            }
        } 
        
        var newEdgeInfo = ""
        for atEdge in atEdges {
            newEdgeInfo = "\(newEdgeInfo), vel \(atEdge.verticalVelocity) dip \(atEdge.position.y - atEdge.verticalZero)"
        }
        if Raylib.isKeyPressed(.letterI) {
            edgeInfo = newEdgeInfo 
        }
        Raylib.drawText("edge info: \(edgeInfo)", 100, screenHeight - 100, 20, Color.black)
    }

    func screenshotStuff() {
        if doScreenshotStuff {
            Raylib.unloadImage(image)
            Raylib.unloadTexture(screenshot)
            image = Raylib.loadImageFromScreen()
            screenshot = Raylib.loadTextureFromImage(image)
        }
    }
}