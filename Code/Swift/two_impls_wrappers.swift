// Valid Swift counterpart of Fortran/two_impls_single.f90: one shared
// protocol and two wrapper types.
//
// Each conformance is declared for a type that the same code owns (in a
// multi-module version, module Plain would declare Plain and module Fancy
// would declare Fancy), so no retroactive conformance of Double is needed and
// the two conformances do not conflict. This changes the original example:
// Double itself does not conform to IPrintable, and each client selects an
// implementation by choosing a wrapper type.
//
// Expected output:
//   plain: 4.9
//   fancy: <<4.9>>
//   plain: 4.9
//   fancy: <<4.9>>

protocol IPrintable {
    func output()
}

struct Plain: IPrintable {
    let value: Double

    func output() {
        print("plain: \(value)")
    }
}

struct Fancy: IPrintable {
    let value: Double

    func output() {
        print("fancy: <<\(value)>>")
    }
}

// Generic code that knows only the protocol.
func show<T: IPrintable>(_ x: T) {
    x.output()
}

func printPlain(_ x: Double) {
    Plain(value: x).output()
}

func printFancy(_ x: Double) {
    Fancy(value: x).output()
}

let y: Double = 4.9
printPlain(y)
printFancy(y)

// Both wrappers satisfy the same protocol constraint.
show(Plain(value: y))
show(Fancy(value: y))
