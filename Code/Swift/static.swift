// ...........
// Interfaces
// ...........

protocol ISum {
    func sum<T: Numeric>(x: [T]) -> T
}

protocol IAverager {
    func average<T: Numeric>(x: [T]) -> T
}

// ..............
// SimpleSum ADT
// ..............

struct SimpleSum: ISum {
    
    func sum<T: Numeric>(x: [T]) -> T {
        var s: T
        s = T(exactly:0)!
        for i in 0 ... x.count-1 {
            s += x[i]
        }
        return s
    }
}

// ................
// PairwiseSum ADT
// ................

struct PairwiseSum<U: ISum>: ISum {    
    var other: U
    
    func sum<T: Numeric>(x: [T]) -> T {
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

struct Averager<U: ISum>: IAverager {    
    var drv: U
    
    func average<T: Numeric>(x: [T]) -> T {
        return drv.sum(x: x)
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

    print( av.average(x: xi) / Int32(xi.count) )
    print( av.average(x: xf) / Float64(xf.count) )
}

// execute main function
main()
