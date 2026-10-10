// Module Plain (Fortran: plain_m): one conformance of Double to IPrintable.
//
// Double (module Swift) and IPrintable (module Printable) are both imported,
// so this is a retroactive conformance. `@retroactive` only acknowledges the
// compiler warning for that case. It neither makes the conformance local to
// this module nor makes a second, different conformance of Double to
// IPrintable (module Fancy) legal: Swift protocol conformance is global to the
// program.
import Printable

extension Double: @retroactive IPrintable {
    public func output() {
        print("plain: \(self)")
    }
}
