// follow https://www.swift.org/install/windows/winget/ to be able to build.
// the exe is stored at .build\x86_64-unknown-windows-msvc\debug
import Raylib

let screenWidth: Int32 = 1280
let screenHeight: Int32 = 720
let FPS = 60

var refCount = 0

Raylib.initWindow(screenWidth, screenHeight, "Salmon Game")
Raylib.setTargetFPS(60)

/*
var water: [WaterColumn] = []

let horzWaterBuf: Int32 = (screenWidth - Int32(Simulation.waterColumnCount * WaterColumn.WIDTH)) / 2
for i in 0..<Simulation.waterColumnCount {
    let column = WaterColumn(position: Vector2(
        x: Float64(horzWaterBuf) + Float64(WaterColumn.WIDTH * i), 
        y: WaterColumn.VERTICAL_ZERO))
    water.append(column)
}

for i in 1..<Simulation.waterColumnCount - 1 {
    water[i].left = water[i - 1]
    water[i].right = water[i + 1] 
}
water[0].right = water[1]
water[water.count - 1].left = water[water.count - 2]

var disturbances: [WaterColumn.Disturbance?] = Array(repeating: nil, count: water.count)

// now for waves, I'm thinking we need access to all columns.
for column in water {
    column.wave?.awareColumns = water
}
/*
["#0 freelyMoving", "#1 freelyMoving", "#2 freelyMoving", "#3 freelyMoving", "#4 freelyMoving", "#5 freelyMoving", "#6 freelyMoving", "#7 freelyMoving", "#8 freelyMoving", "#9 atEdge", "activated on #9 atEdge", "#10 beingDisturbed", "#11 beingDisturbed", "#12 beingDisturbed", "#13 beingDisturbed", "#14 beingDisturbed", "#15 beingDisturbed", "#16 beingDisturbed", "#17 beingDisturbed", "#18 beingDisturbed", "#19 atEdge", "activated on #19 atEdge", "#20 freelyMoving", "#21 freelyMoving", "#22 freelyMoving", "#23 freelyMoving", "#24 freelyMoving", "#25 freelyMoving", "#26 freelyMoving", "#27 freelyMoving", "#28 freelyMoving"]
*/
let dists: [WaterColumn.Disturbance] = [
    .freelyMoving, .freelyMoving, .freelyMoving, 
    .freelyMoving, .freelyMoving, .freelyMoving, 
    .freelyMoving, .freelyMoving, .freelyMoving, 
    .atEdge, .beingDisturbed, .beingDisturbed, 
    .beingDisturbed, .beingDisturbed, .beingDisturbed, 
    .beingDisturbed, .beingDisturbed, .beingDisturbed, 
    .atEdge, .freelyMoving, .freelyMoving, 
    .freelyMoving, .freelyMoving, .freelyMoving, 
    .freelyMoving, .freelyMoving,.freelyMoving, 
    .freelyMoving
]
for (disturbance, column) in zip(dists, water) {
    column.disturbance = disturbance
}

func calc(_ i: Int) {
    return 
}

for i in 0..<water.count {
    let column = water[i]

    let disturbed = calc(i)
}

for column in water {
    column.left = nil
    column.right = nil
    column.wave = nil
}
*/

// to keep ref counted objects in a finite scope, so that the proper number can be printed at the end of the program
do {
    let simulation = Simulation()

    while !Raylib.windowShouldClose {
        Raylib.beginDrawing()

        simulation.update()

        Raylib.clearBackground(Color.white)
        Raylib.drawFPS(10, 10)
        Raylib.drawText("refs: \(refCount)", screenWidth - 100, screenHeight - 30, 2, Color.black)
        Raylib.endDrawing()
    }
}

Raylib.closeWindow()
print("refs: \(refCount)")