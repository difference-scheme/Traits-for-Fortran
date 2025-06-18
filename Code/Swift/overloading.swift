protocol IReducible {
    init<T: BinaryInteger>(_ n: T)
    static func * (lhs: Self, rhs: Self) -> Self
    static func * (lhs: Self, rhs: Int) -> Self
}

protocol IPrintable {
    func output()
}

struct MyType {
    private let n: Int
}

extension MyType: IReducible, IPrintable {
    init<T: BinaryInteger>(_ n: T) {
        self.n = Int(n)
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
    var res = T(1)
    for i in 0 ..< arr.count {
        res = res * arr[i]
    }
    return res
}

func products<T: IReducible & IPrintable,
              R: IReducible & IPrintable>(at: inout [T], ar: inout [R]) {    
    let ai = [4,3,2,1]
    
    for i in 0 ..< at.count {
        at[i] = (at[i] * at[i]) * ai[i]
    }

    for i in 0 ..< ar.count {
        ar[i] = (ar[i] * ar[i]) * ai[i]
    }

    // calculate reduction of arrays of both types
    let st = prod(arr: at)
    let sr = prod(arr: ar)    
    
    st.output()
    sr.output()
}

func main() {
    var at = [MyType(1),MyType(2),MyType(3),MyType(4)]
    var ar = [1.0,2.0,3.0,4.0]
    
    // print the results
    products(at: &at, ar: &ar)
}

main()
