// follow https://www.swift.org/install/windows/winget/ to be able to build.
// the exe is stored at .build\x86_64-unknown-windows-msvc\debug
import Raylib

let screenWidth: Int32 = 1280
let screenHeight: Int32 = 720
let FPS = 60

var refCount = 0

Raylib.initWindow(screenWidth, screenHeight, "Salmon Game")
Raylib.setTargetFPS(60)

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