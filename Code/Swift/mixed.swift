// ...........
// Interfaces
// ...........

protocol INumeric {
    init?(exactly: Int)
    static func += (lhs: inout Self, rhs: Self)
    static func + (lhs: Self, rhs: Self) -> Self
    static func / (lhs: Self, rhs: Self) -> Self
}

protocol ISum {
    func sum<T: INumeric>(x: [T]) -> T
}

protocol IAverager {
    func average<T: INumeric>(x: [T]) -> T
}

// ...........
// Intrinsics
// ...........

extension Int32: INumeric {}
extension Float64: INumeric {}

// ..............
// SimpleSum ADT
// ..............

struct SimpleSum: ISum {    
    func sum<T: INumeric>(x: [T]) -> T {
        var s = T(exactly:0)!
        for i in 0 ..< x.count {
            s += x[i]
        }
        return s
    }
}

// ................
// PairwiseSum ADT
// ................

struct PairwiseSum: ISum {    
    private let other: any ISum

    init(other: any ISum) {
        self.other = other
    }
    
    func sum<T: INumeric>(x: [T]) -> T {
        if x.count <= 2 {
            return other.sum(x: x)
        } else {
            let m = x.count / 2
            return sum(x: Array(x[..<m])) + sum(x: Array(x[m...]))
        }
    }
}

// .............
// Averager ADT
// .............

struct Averager: IAverager {    
    private let drv: any ISum

    init(drv: any ISum) {
        self.drv = drv
    }
    
    func average<T: INumeric>(x: [T]) -> T {
        return drv.sum(x: x) / T(exactly: x.count)!
    }
}

// ..............
// main function
// ..............

func main() {
    let av: any IAverager
    let key: Int32?

    print("Simple   sum average: 1")
    print("Pairwise sum average: 2")
    print("Choose an averaging method: ", terminator: "")
    key = Int32(readLine()!)
    
    switch key {
    case 1:
        av = Averager(drv: SimpleSum())
    case 2:
        av = Averager(drv: PairwiseSum(other: SimpleSum()))
    default:
        print("Case not implemented!")
        return
    }

    let xi: [Int32] = [1,2,3,4,5]
    let xf: [Float64] = [1.0,2.0,3.0,4.0,5.0]
    
    print( av.average(x: xi) )
    print( av.average(x: xf) )
}

// execute main function
main()
