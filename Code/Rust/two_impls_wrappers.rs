// Working Rust adaptation of Fortran/two_impls_single.f90 using wrapper
// (newtype) types.
//
// There is still one shared trait, printable_m::IPrintable, but the two
// implementations are now for two different types, Plain and Fancy, so they
// do not conflict. This changes the original example: f64 itself does not
// implement IPrintable, and each client selects an implementation by choosing
// a wrapper type, not by a `use` declaration.
//
// Expected output:
//   plain:   4.90
//   fancy: <<    4.9000E0>>
//   plain:   4.90
//   fancy: <<    4.9000E0>>

pub mod printable_m {
    pub trait IPrintable {
        fn output(&self);
    }

    // Generic code that knows only the trait.
    pub fn show<T: IPrintable>(x: &T) {
        x.output();
    }
}

// Library A
pub mod plain_m {
    use crate::printable_m::IPrintable;

    pub struct Plain(pub f64);

    impl IPrintable for Plain {
        fn output(&self) {
            println!("plain: {:6.2}", self.0);
        }
    }
}

// Library B
pub mod fancy_m {
    use crate::printable_m::IPrintable;

    pub struct Fancy(pub f64);

    impl IPrintable for Fancy {
        fn output(&self) {
            println!("fancy: <<{:12.4E}>>", self.0);
        }
    }
}

fn print_plain(x: f64) {
    use crate::plain_m::Plain;
    use crate::printable_m::IPrintable;
    Plain(x).output();
}

fn print_fancy(x: f64) {
    use crate::fancy_m::Fancy;
    use crate::printable_m::IPrintable;
    Fancy(x).output();
}

fn main() {
    use crate::fancy_m::Fancy;
    use crate::plain_m::Plain;
    use crate::printable_m::show;

    let y: f64 = 4.9;
    print_plain(y);
    print_fancy(y);

    // Both wrappers satisfy the same trait bound.
    show(&Plain(y));
    show(&Fancy(y));
}
