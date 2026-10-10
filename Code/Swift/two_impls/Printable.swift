// Module Printable (Fortran: printable_m): the shared protocol.
public protocol IPrintable {
    func output()
}

// Generic code that knows only the protocol; it uses the conformance that its
// caller passes in.
public func show<T: IPrintable>(_ x: T) {
    x.output()
}
