protocol IPrintable {
    func output()
}
extension Float64: IPrintable {
    func output() {
        print("I am \(self)")
    }
}
var x: Float64 = 4.9
x.output()
