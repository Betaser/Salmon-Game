import Raylib
import Foundation

class Test1 : State {
    // 19 * 6
    // static let WATER_COLUMN_COUNT: Int32 = 35
    static let WATER_COLUMN_COUNT: Int32 = 9
    var water: [WaterColumn] = []
    var counter: Int32
    static var DEBUG_COUNTER: Int32 = 0
    static var COLUMN_BOTTOM = screenHeight - 100
    var simSpeed = 0.0
    var leftoverSpeed = 0.0

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

        let horzWaterBuf: Int32 = (screenWidth - Int32(Self.WATER_COLUMN_COUNT * WaterColumn.WIDTH)) / 2

        for i in 0..<Self.WATER_COLUMN_COUNT {
            let column = WaterColumn(
                position: Vec2(
                    x: Float64(horzWaterBuf) + Float64(WaterColumn.WIDTH * i), 
                    y: WaterColumn.VERTICAL_ZERO),
                waterColumnCount: Self.WATER_COLUMN_COUNT,
                width: WaterColumn.WIDTH)
            water.append(column)
        }

        // now set the left and right columns.
        for i in 1..<Int(Self.WATER_COLUMN_COUNT - 1) {
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
        leftoverSpeed += (simSpeed.truncatingRemainder(dividingBy: 1)) 
        if leftoverSpeed >= 1 {
            leftoverSpeed -= 1

            manageWater()
        }
        for _ in 0..<Int(simSpeed) {
            manageWater()
        }
    }

    func manageWater() {
        // update water loop
        do {
            if true {
                var closureSeqs: [WaterColumn.AllGAS] = []
                var closureGASes: [(WaterColumn.G, WaterColumn.S)] = []
                var maxIndices: [UInt] = []

                for col in water {
                    let (maxIndex, closures) = col.updateGAS()
                    maxIndices.append(maxIndex)
                    if closures.count > 0 {
                        closureSeqs.append(closures) 
                        closureGASes.append((col.getter, col.setter))
                    }
                }

                // debugging
                for col in water {
                    print("\(col.wave.vacuum?.strength ?? -1) debugging on line 106 Test1.swift")
                }

                let seqCount = closureSeqs.count
                let closureMaxDepth = maxIndices.max() ?? 0

                var depth: UInt = 0
                var distances: [Int] = []
                for i in 0..<seqCount {
                    let firstClosureDist = closureSeqs[i][0].0
                    distances.append(Int(firstClosureDist))
                }

                while depth <= closureMaxDepth {
                    var seqI = 0
                    
                    func breadth() {
                        if seqI >= seqCount {
                            return
                        }

                        let dist = distances[seqI]

                        var setter: (((WaterColumn.S) -> Void), WaterColumn.S)? = nil
                        if dist > 0 {
                            distances[seqI] -= 1
                        } else if dist == 0 {
                            let (depth, gASConsumers) = closureSeqs[seqI][0]
                            let getterConsumer = gASConsumers.0
                            getterConsumer(closureGASes[seqI].0)
                            setter = (gASConsumers.1, closureGASes[seqI].1)

                            closureSeqs[seqI].remove(at: 0)
                            distances[seqI] = if closureSeqs[seqI].count == 0 {
                                -1
                            } else {
                                Int(closureSeqs[seqI][0].0 - depth - 1)
                            }
                        } else {
                            // print("skipped closures for \(seqI)")
                        }

                        seqI += 1
                        breadth()

                        if let setter = setter {
                            setter.0(setter.1)
                        }
                    }

                    breadth()

                    depth += 1
                }
            }

            // Bestest attempt
            if false {
                var closureSeqs: [UpdateClosures] = []
                var maxIndices: [UInt] = []

                for col in water {
                    let (maxIndex, closures) = col.update()
                    maxIndices.append(maxIndex)
                    if closures.count > 0 {
                        closureSeqs.append(closures) 
                    }
                }

                let seqCount = closureSeqs.count
                let closureMaxDepth = maxIndices.max() ?? 0

                var depth: UInt = 0
                var distances: [Int] = []
                for i in 0..<seqCount {
                    distances.append(Int(closureSeqs[i][0].0))
                }

                while depth <= closureMaxDepth {
                    var seqI = 0
                    
                    func breadth() {
                        if seqI >= seqCount {
                            return
                        }

                        let dist = distances[seqI]

                        var closureFunc: (() -> Void)? = nil
                        if dist > 0 {
                            distances[seqI] -= 1
                        } else if dist == 0 {
                            let (depth, closureChain) = closureSeqs[seqI][0]
                            closureFunc = closureChain()

                            closureSeqs[seqI].remove(at: 0)
                            distances[seqI] = if closureSeqs[seqI].count == 0 {
                                -1
                            } else {
                                Int(closureSeqs[seqI][0].0 - depth - 1)
                            }
                        } else {
                            // print("skipped closures for \(seqI)")
                        }

                        seqI += 1
                        breadth()

                        if let closure = closureFunc {
                            closure()
                        }
                    }

                    breadth()

                    depth += 1
                }
            }
 
            // Better attempt
            /*
                var closureDists: [(Int, Int)] = []
                for i in 0..<allClosures.count {
                    closureDists.append((i, 0))
                }

                var closureI: UInt = 0
                var distI = 0
                let next: () -> (Int, Int)? = {
                    if distI > closureDists.count - 1 {
                        return nil
                    }
                    let indexAndDist = closureDists[distI]
                    distI += 1
                    return indexAndDist
                }

                // Help, does not go thru multiple layers of closures
                
                let maxIndex = if let max = maxIndices.max() {
                    Int(max)
                } else {
                    -1
                }

                for i in 0..<maxIndex {
                    // match below loop contents, but make sure to reset distI
                    distI = 0
                }

                // Only runs once which is very dumb.
                while distI < closureDists.count {
                    func loop() {
                        if let (allClosuresI, dist) = next() {
                            // Decrement dist
                            closureDists[distI - 1].1 -= 1

                            if dist > 0 {
                                assert(false)
                                loop()
                            }

                            let closures = allClosures[allClosuresI]
                            var possibleClosure = {}

                            if let closure = closures[closureI] {
                                possibleClosure = closure()
                            } else if closureI >= maxIndices[allClosuresI] {
                                assert(false)
                                // Hack for "deleting" it
                                _ = next()
                            } else {
                                // We should always have a closure to find.
                                assert(false)
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
            */

            /*
            if false {
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
            */
        }
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
            let disturbedColumnIndex = Int(Self.WATER_COLUMN_COUNT / 2)

            // Let's pretend we did in fact disturb the water with an object of one column width.
            let left = disturbedColumnIndex - 1
            let right = disturbedColumnIndex + 1
            let disturbAmt = 0.5
            water[left].wave.horzVel = -disturbAmt
            water[right].wave.horzVel = disturbAmt
            // water[disturbedColumnIndex].wave.horzVel = 0.5
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

        if frameByFrame {
            manageWater()
        } else {
            manageSimSpeed()
        }

        for column in water {
            column.render(bottom: Self.COLUMN_BOTTOM, vScale: WaterColumn.V_SCALE)
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