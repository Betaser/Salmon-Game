import Foundation
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

class Vector2 {
    var x: Float64
    var y: Float64
    init(x: Float64, y: Float64) {
        self.x = x
        self.y = y
    }
    func clone() -> Vector2 {
        return Vector2(x: x, y: y)
    }
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