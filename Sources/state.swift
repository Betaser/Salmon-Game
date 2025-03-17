protocol State {
    func update()
    func screenshotUpdate() 
}

// Empty default implementations
extension State {
    func screenshotUpdate() {}
}