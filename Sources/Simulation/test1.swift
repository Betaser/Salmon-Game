// the only current state.
import Raylib
import Foundation

class Test1 : State {
    static let waterColumnCount = 19 * 6
    static let disturbanceCount = 9 * 6
    var water: [WaterColumn] = []
    var counter: Int32
    static var DEBUG_COUNTER: Int32 = 0
    var simSpeed = 0.0
    var leftoverSpeed = 0.0
    let disturbance = WaterDisturbance(columnCount: disturbanceCount)

    var frameByFrame = false
    var screenshot = Texture()
    var image = Image()
    var doScreenshotStuff = true
    var screenshotDelay = 1

    init() {
        counter = 0
        reinit()
    }

    func reinit() {
        water.removeAll()
        counter = 0
        simSpeed = 1.0
        leftoverSpeed = 0.0

        let horzWaterBuf: Int32 = (screenWidth - Int32(Self.waterColumnCount * WaterColumn.WIDTH)) / 2

        for i in 0..<Self.waterColumnCount {
            let column = WaterColumn(
                position: Vec2(
                    x: Float64(horzWaterBuf) + Float64(WaterColumn.WIDTH * i), 
                    y: WaterColumn.VERTICAL_ZERO),
                waterColumnCount: Self.waterColumnCount)
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

            text = manageWater()
        }
        for _ in 0..<Int(simSpeed) {
            text = manageWater()
        }

        if let text = text {
            Raylib.drawText(text.0, text.1, text.2, text.3, text.4)
        }
    }

    var lastEdgeVel = 0.0
    func manageWater() -> (String, Int32, Int32, Int32, Color) {
        // update water loop
        // do first, because disturbance setting requires a proper initialization of crushing.

        var waveData: [(Float64, Float64)] = []
        for col in water {
            waveData.append((col.left?.horzVelocity ?? 0, col.right?.horzVelocity ?? 0))
        }

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

        if Raylib.isKeyPressed(.letterR) {
            reinit()
            return
        }

        if Raylib.isKeyPressed(.space) {
            let halfOffset = (Self.waterColumnCount - disturbance.columnCount) / 2
            let disturbedSlice = water[halfOffset..<Self.waterColumnCount - halfOffset]
            disturbance.crushColumns(columns: disturbedSlice)
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
            let text: (String, Int32, Int32, Int32, Color) = manageWater()
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
        Raylib.drawText("Controls: \nR to reset simulation\nSpace to create wave\nT to toggle frame by frame analysis", 100, 150, 20, Color.darkGreen)
    }

    func screenshotUpdate() {
        if doScreenshotStuff {
            Raylib.unloadImage(image)
            Raylib.unloadTexture(screenshot)
            image = Raylib.loadImageFromScreen()
            screenshot = Raylib.loadTextureFromImage(image)
        }
    }
}