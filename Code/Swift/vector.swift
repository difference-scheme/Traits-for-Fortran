public protocol IAppendable {
    associatedtype Element
    mutating func append(_ item: Element)
}

struct Vector<U>: IAppendable {
    private var elements: [U]
    
    init(_ item: U) {
        self.elements = [item]
    }

    mutating func append(_ item: U) {
        self.elements.append(item)
    }

    func printout() {
        print(elements)
    }
}

var doubles = Vector(0.0)
doubles.append(1.5)
doubles.append(2.2)
doubles.printout()
    
var bools = Vector<Bool>(true)
bools.append(false)
bools.append(true)
bools.printout()

var strings = Vector("John")
strings.append("Mary")
strings.append("Anne")
strings.printout()
