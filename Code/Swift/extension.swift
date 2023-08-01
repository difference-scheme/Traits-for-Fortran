protocol IPrinter {
    func out()
}
extension Float64: IPrinter {
    func out() {
        print("I am \(self)")
    }
}
var x: Float64 = 4.9
x.out()
