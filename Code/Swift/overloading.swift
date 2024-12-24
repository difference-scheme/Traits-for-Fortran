protocol IReducible {
    init?<T: BinaryInteger>(exactly: T)
    static func * (lhs: Self, rhs: Self) -> Self
    static func * (lhs: Self, rhs: Int) -> Self
}

protocol IPrintable {
    func output()
}


struct MyType {
    var n: Int
}

extension MyType: IReducible, IPrintable {
    init?<T: BinaryInteger>(exactly: T) {
        self.n = Int(exactly)
    }
    static func * (lhs: MyType, rhs: MyType) -> MyType {        
        return MyType(n: lhs.n * rhs.n)
    }
    static func * (lhs: MyType, rhs: Int) -> MyType {        
        return MyType(n: lhs.n * rhs)
    }
    func output() {
        print("I am: \(self.n)") 
    }
}

extension Float64: IReducible, IPrintable {
    static func * (lhs: Float64, rhs: Int) -> Float64 {        
        return lhs * Float64(rhs)
    }
    func output() {
        print("I am: \(self)")
    }
}

func prod<T: IReducible>(arr: [T]) -> T {
    var res: T
    res = T(exactly: 1)!
    for i in 0 ..< arr.count {
        res = res * arr[i]
    }
    return res
}

func products<T: IReducible & IPrintable,
              R: IReducible & IPrintable>(at: inout [T], ar: inout [R]) {    
    var st: T
    var sr: R

    let ai: [Int] = [4,3,2,1]
    
    for i in 0 ..< at.count {
        at[i] = (at[i] * at[i]) * ai[i]
    }

    for i in 0 ..< ar.count {
        ar[i] = (ar[i] * ar[i]) * ai[i]
    }

    // calculate reduction of arrays of both types
    st = prod(arr: at)
    sr = prod(arr: ar)    
    
    st.output()
    sr.output()
}

func main() {

    var at: [MyType]  = [MyType(n:1),MyType(n:2),MyType(n:3),MyType(n:4)]
    var ar: [Float64] = [1.0,2.0,3.0,4.0]

    // print the results
    products(at: &at, ar: &ar)
}

main()
