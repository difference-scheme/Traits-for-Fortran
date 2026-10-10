// Module FancyClient (Fortran: print_fancy with `use fancy_m`): depends on the
// provider it wants, Fancy, and not on Plain.
import Fancy
import Printable

public func printFancy(_ x: Double) {
    x.output()
}

// Generic forwarding: show(_:) receives the conformance visible here (Fancy's).
public func showFancy(_ x: Double) {
    show(x)
}
