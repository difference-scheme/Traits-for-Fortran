// One implementation of a shared trait for f64 (compare Fortran/printy.f90).
//
// The client imports only the trait. It never names `plain_m`, the module that
// contains the implementation: `use` binds names, and impls are not named
// items. The impl is found because coherence allows at most one
// `impl IPrintable for f64` in the whole crate graph, so there is nothing to
// choose. (If printable_m were a separate crate, the orphan rule would require
// this impl, for the foreign type f64, to live in that crate.)
//
// Expected output:
//   plain:   4.90

pub mod printable_m {
    pub trait IPrintable {
        fn output(&self);
    }
}

// The only implementation of IPrintable for f64 in this program.
mod plain_m {
    use crate::printable_m::IPrintable;

    impl IPrintable for f64 {
        fn output(&self) {
            println!("plain: {:6.2}", self);
        }
    }
}

fn print_it(x: f64) {
    use crate::printable_m::IPrintable; // the trait only; no `use crate::plain_m`
    x.output();
}

fn main() {
    let y: f64 = 4.9;
    print_it(y);
}
