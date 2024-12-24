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
        var s: T
        s = T(exactly:0)!
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
    var other: ISum
    
    func sum<T: INumeric>(x: [T]) -> T {
        if ( x.count <= 2 ) {
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
    var drv: ISum
    
    func average<T: INumeric>(x: [T]) -> T {
        return drv.sum(x: x) / T(exactly: x.count)!
    }
}

// ..............
// main function
// ..............

func main() {
    let avs = Averager(drv: SimpleSum())
    let avp = Averager(drv: PairwiseSum(other: SimpleSum()))

    var av : IAverager = avs
    
    let xi: [Int32] = [1,2,3,4,5]
    let xf: [Float64] = [1.0,2.0,3.0,4.0,5.0]
    
    var key: Int32?

    print("Simple   sum average: 1")
    print("Pairwise sum average: 2")
    print("Choose an averaging method: ")
    key = Int32(readLine()!)
    
    switch key {
    case 1:
        // simple sum case
        av = avs
    case 2:
        // pairwise sum case
        av = avp
    default:
        print("Case not implemented!")
        return
    }

    print( av.average(x: xi) )
    print( av.average(x: xf) )
}

// execute main function
main()
