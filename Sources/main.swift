// follow https://www.swift.org/install/windows/winget/ to be able to build.
// the exe is stored at .build\x86_64-unknown-windows-msvc\debug
import Raylib

let screenWidth: Int32 = 1280
let screenHeight: Int32 = 720
let FPS: Int32 = 60

var refCount = 0

// Means no logging from Raylib itself.
Raylib.setTraceLogLevel(TraceLogLevel.none)

Raylib.initWindow(screenWidth, screenHeight, "Salmon Game")
Raylib.setTargetFPS(FPS)

do {

    // to keep ref counted objects in a finite scope, so that the proper number can be printed at the end of the program
    let oldSimulation = OldSimulation()
    let test1 = Test1()
    let helpMenu = HelpMenuState()

    // Current plan: Create a vertical options list for what GameState to run
    let debugMenu = DebugMenuState()

    debugMenu.addOption(oldSimulation)
    debugMenu.addOption(test1)
    debugMenu.addOption(helpMenu)

    var activeState: State = debugMenu

    while !Raylib.windowShouldClose {
        Raylib.beginDrawing()
        Raylib.clearBackground(Color.white)

        activeState.update()

        Raylib.drawFPS(10, 10)
        Raylib.drawText("refs: \(refCount)", screenWidth - 100, screenHeight - 30, 2, Color.black)
        Raylib.endDrawing()

        activeState.screenshotUpdate()
    }
}

Raylib.closeWindow()
print("refs: \(refCount)")