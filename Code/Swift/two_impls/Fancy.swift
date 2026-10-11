// Module Fancy (Fortran: fancy_m): a different conformance of Double to the
// same protocol. A program that links both Plain and Fancy contains duplicate
// conformances, which Swift does not support (see Plain.swift).
import Printable

extension Double: @retroactive IPrintable {
    public func output() {
        print("fancy: <<\(self)>>")
    }
}
