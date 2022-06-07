func topLevelFunc(_ anInt: Int) -> String {
    .init(anInt)
}

struct ValueVsType {
    var valueLevelFunc: (Int) -> String = { anInt in .init(anInt) }

    static func staticLevelFunc(_ anInt: Int) -> String {
        .init(anInt)
    }
    func typeLevelFunc(_ anInt: Int) -> String {
        .init(anInt)
    }
}

let valueVsType: ValueVsType = .init()

type(of: topLevelFunc)
type(of: ValueVsType.staticLevelFunc)
type(of: valueVsType.valueLevelFunc)
type(of: valueVsType.typeLevelFunc)
type(of: ValueVsType.typeLevelFunc(valueVsType))
type(of: ValueVsType.typeLevelFunc)


let array: [CustomStringConvertible] = [
    1,
    "two",
    3.0
]

type(of: array[0])
//let i = array[0] + 4
