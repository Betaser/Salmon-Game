import Foundation
import Raylib

// Mathy
func toTuple(_ v: Vector2) -> (Float64, Float64) {
    return (Float64(v.x), Float64(v.y))
}

// Use Raylib.Vector, fully qualified name to differentiate
struct Vec2 {
    var x: Float64
    var y: Float64
    init(x: Float64, y: Float64) {
        self.x = x
        self.y = y
    }
    func clone() -> Self {
        return Self(x: x, y: y)
    }
}

struct Rect {
    var x: Float64
    var y: Float64
    var width: Float64
    var height: Float64

    init() {
        x = 0
        y = 0
        width = 0
        height = 0
    }

    init(_ x: Float64, _ y: Float64, _ width: Float64, _ height: Float64) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    mutating func fromInts(_ x: Int32, _ y: Int32, _ width: Int32, _ height: Int32) -> Self {
        self.x = Float64(x)
        self.y = Float64(y)
        self.width = Float64(width)
        self.height = Float64(height)
        return self
    }

    func toInts() -> (Int32, Int32, Int32, Int32) {
        return (Int32(x), Int32(y), Int32(width), Int32(height))
    }

    func pointInside(_ point: (Float64, Float64)) -> Bool {
        return
            x <= point.0 && point.0 <= x + width &&
            y <= point.1 && point.1 <= y + height
    }
}

// Codey
typealias UpdateClosures = [UInt : () -> () -> Void]

func triangleValley(range: Range<Float64>, input: Float64) -> Float64 {
    let center = (range.upperBound - range.lowerBound) / 2
    let normalizedX = (input - center) / ((range.upperBound - range.lowerBound) / 2)
    return abs(normalizedX)
}

func parabola(range: Range<Float64>, input: Float64) -> Float64 {
    let center = (range.upperBound - range.lowerBound) / 2
    let normalizedX = (input - center) / ((range.upperBound - range.lowerBound) / 2)
    return 1 - pow(normalizedX, 2)
}
// multiply it by 200 * 1.7 = 340

struct DiscreteFunction {
    let stepSize: Float64
    let xYFunction: (Float64) -> Float64

    func getOutputs(range: Range<Float64>) -> [Float64] {
        var outputs: [Float64] = []
        var x = range.lowerBound
        while x < range.upperBound {
            outputs.append(xYFunction(x)) 
            x += stepSize
        }
        return outputs
    }
}

func indexExprsAndMax(exprs: [(() -> () -> Void)?]) -> (UInt, UpdateClosures) {
    var index: UInt = 0
    var maxIndex: UInt = 0
    var dict = UpdateClosures()
    for expr in exprs {
        if let expr = expr {
            maxIndex = index
            dict[index] = expr
        }
        index += 1
    }

    return (maxIndex, dict)
}

extension Collection {
    // Some collections do not use Ints as Indices
    func get(_ i: Int) -> Element? where Index == Int {
        let offset = i >= 0 ? i : i + count
        if offset >= count {
            return nil
        }
        // Use startIndex in case the current collection is a slice
        return self[index(startIndex, offsetBy: offset)]
    }
}

struct Generic {
    func staticCreate<T>(_ mkObj: () -> T) -> T {
        refCount -= 1
        return mkObj()
    }
    static let inst = Self()
}