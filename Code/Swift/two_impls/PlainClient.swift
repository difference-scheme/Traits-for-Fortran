// Module PlainClient (Fortran: print_plain with `use plain_m`): depends on the
// provider it wants, Plain, and not on Fancy.
import Plain
import Printable

public func printPlain(_ x: Double) {
    x.output()
}

// Generic forwarding: show(_:) receives the conformance visible here (Plain's).
public func showPlain(_ x: Double) {
    show(x)
}
