// follow https://www.swift.org/install/windows/winget/ to be able to build.
// the exe is stored at .build\x86_64-unknown-windows-msvc\debug
import Raylib

let screenWidth: Int32 = 1280
let screenHeight: Int32 = 720
let FPS = 60

Raylib.initWindow(screenWidth, screenHeight, "Salmon Game")
Raylib.setTargetFPS(60)

let simulation = Simulation()

while !Raylib.windowShouldClose {
    Raylib.beginDrawing()

    simulation.update()

    Raylib.clearBackground(Color.white)
    Raylib.drawFPS(10, 10)
    Raylib.endDrawing()
}

Raylib.closeWindow()