protocol IPrintable {
    func out()
}
extension Float64: IPrintable {
    func out() {
        print("I am \(self)")
    }
}
var x: Float64 = 4.9
x.out()
