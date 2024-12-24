protocol IPrintable {
    func output()
}
extension Float64: IPrintable {
    func output() {
        print("I am \(self)")
    }
}
var y: Float64 = 4.9
y.output()
