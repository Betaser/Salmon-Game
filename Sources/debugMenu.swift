import Raylib

class DebugMenuState : State {
    var descriptionToState: [(String, State)] = []
    // Store all states except self

    // Run the current state but also run wrapper code for a back button.
    var currentState: State? = nil

    var scrollAmt: Int32 = 0

    func addOption(_ option: State) {
        let tryDescription: String? = 
            switch option {
                case is OldSimulation: "Old simulation"
                case is Test4: "Test 4, disruption"
                case is Test3: "Test 3, disruption without peak wave"
                case is Test2: "Test 2, water settling to a stop"
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
        let evenMiddle = descriptionToState.count % 2 == 0
            ? Int32(VERT_GAP + HEIGHT) / 2
            : Int32(0)

        let mouseMovement = Raylib.getMouseWheelMove() 
        if mouseMovement != 0 {
            // pos mouseMovement = upwards
            scrollAmt += Int32(mouseMovement * 5.0)
            // Offset everything by scrollAmt
            let GUTTER: Int32 = 15
            let lowestPos = 
                (screenHeight / 2
                - HEIGHT / 2
                - Int32(descriptionToState.count / 2 - descriptionToState.count + 1) * (VERT_GAP + HEIGHT)
                + HEIGHT
                + evenMiddle)
            // Since lowestPos is being added as scrollAmt in the scrolled furtherest case, move it to the bottom of the screen.
            let lowerBound = -lowestPos + screenHeight - GUTTER
            scrollAmt = max(lowerBound, scrollAmt)
            // with evenMiddle this is in magnitude equal
            let upperBound = -lowerBound
            scrollAmt = min(upperBound, scrollAmt)
        }

        var index: Int32 = 0

        for (desc, state) in descriptionToState {
            let rectY = screenHeight / 2 
                - HEIGHT / 2
                - (Int32(descriptionToState.count / 2) - index) * (VERT_GAP + HEIGHT)
                + scrollAmt
                + evenMiddle

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