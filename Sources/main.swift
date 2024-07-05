// follow https://www.swift.org/install/windows/winget/ to be able to build.
// the exe is stored at .build\x86_64-unknown-windows-msvc\debug
import Raylib

let column = WaterColumn(position: Vector2(x: 100, y: 100))

let screenWidth: Int32 = 1280
let screenHeight: Int32 = 720
Raylib.initWindow(screenWidth, screenHeight, "Salmon Game")
Raylib.setTargetFPS(60)

while !Raylib.windowShouldClose {
    Raylib.beginDrawing()

    Raylib.drawText("\(column.position.x)", 200, 100, 20, Color.black)

    Raylib.clearBackground(Color.white)
    Raylib.drawFPS(10, 10)
    Raylib.endDrawing()
}

Raylib.closeWindow()