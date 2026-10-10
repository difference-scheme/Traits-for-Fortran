// Literal Rust translation of Fortran/two_impls_single.f90.
//
// EXPECTED TO FAIL TO COMPILE with
//   error[E0119]: conflicting implementations of trait `IPrintable` for type `f64`
//
// plain_m and fancy_m implement the same trait, printable_m::IPrintable, for
// the same type, f64. Coherence allows at most one such impl in the whole
// crate graph, so the program is rejected where the impls are defined. The
// clients below import only the shared trait, and no `use` could help: `use`
// binds names and cannot select an impl.
//
// The modules are kept in one crate on purpose. As separate crates, each
// `impl printable::IPrintable for f64` would already be rejected on its own
// by the orphan rule (E0117).
//
// Compiling variants: single_impl.rs and two_impls_wrappers.rs.

pub mod printable_m {
    pub trait IPrintable {
        fn output(&self);
    }
}

// Library A: one implementation of IPrintable for f64
pub mod plain_m {
    use crate::printable_m::IPrintable;

    impl IPrintable for f64 {
        fn output(&self) {
            println!("plain: {:6.2}", self);
        }
    }
}

// Library B: a different implementation for the same type
pub mod fancy_m {
    use crate::printable_m::IPrintable;

    impl IPrintable for f64 {
        fn output(&self) {
            println!("fancy: <<{:12.4E}>>", self);
        }
    }
}

fn print_plain(x: f64) {
    use crate::printable_m::IPrintable;
    x.output();
}

fn print_fancy(x: f64) {
    use crate::printable_m::IPrintable;
    x.output();
}

fn main() {
    let y: f64 = 4.9;
    print_plain(y);
    print_fancy(y);
}
