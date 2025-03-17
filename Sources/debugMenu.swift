import Raylib

class DebugMenuState : State {
    var descriptionToState: [(String, State)] = []
    // Store all states except self

    // Run the current state but also run wrapper code for a back button.
    var currentState: State? = nil

    func addOption(_ option: State) {
        let tryDescription: String? = 
            switch option {
                case is OldSimulation: "Old simulation"
                case is Test1: "Test 1, propagating wave"
                case is HelpMenuState: "Help menu"
                default: nil
            }

        if let d = tryDescription {
            descriptionToState.append((d, option))
        }
    }

    func update() {
        if let state = currentState {
            // Then create a back button, otherwise don't since we are in debugMenu
            state.update()

            // Render back button
            var rect = Rect()
            rect = rect.fromInts(screenWidth - 150, 50, 100, 100)
            let ints = rect.toInts()
            var color = Color.darkGray
            color.a = 100
            Raylib.drawRectangle(ints.0, ints.1, ints.2, ints.3, color)
            Raylib.drawText("back", Int32(rect.x), Int32(rect.y), 30, Color.white)

            if rect.pointInside(toTuple(Raylib.getMousePosition())) {
                if Raylib.isMouseButtonReleased(.left) {
                    currentState = nil
                }
            }

            return
        } 

        let VERT_GAP = screenHeight / 12
        let HEIGHT = screenHeight / 8
        let HORZ_GAP = screenWidth / 4

        var index = Int32(0)

        for (desc, state) in descriptionToState {
            let rectY = screenHeight / 2 
                - (Int32(descriptionToState.count / 2) - index) * (VERT_GAP + HEIGHT) 
                - HEIGHT / 2

            var rect = Rect()
            rect = rect.fromInts(
                HORZ_GAP / 2,
                rectY,
                screenWidth - HORZ_GAP,
                HEIGHT
            )

            // Mouse position in Rect object (make in misc) = switch currentState.
            if rect.pointInside(toTuple(Raylib.getMousePosition())) {
                if Raylib.isMouseButtonReleased(.left) {
                    currentState = state
                }
            }

            let iRect = rect.toInts()
            Raylib.drawRectangle(iRect.0, iRect.1, iRect.2, iRect.3, Color.green)
            Raylib.drawText(
                desc,
                HORZ_GAP / 2 + 15,
                rectY + 12,
                40,
                Color.black)
            index += 1
        }
    }
}

class HelpMenuState : State {
    func update() {
        print("Left click one of the options to switch to that game state.")
    }
}