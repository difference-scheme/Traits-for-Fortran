# Traits, Generics, and Modern-day OOP for Fortran

A traits system for Fortran is described. Its aim is to endow the
language with state-of-the-art capabilities for *both* compile-time
and run-time polymorphism, that are similar to those of the Swift,
Rust, Go, or Carbon languages.

We have surveyed all these latter modern languages in order to distill
their very best features with respect to polymorphism, and to tie them
into a coherent and consistent package of extensions for Fortran, that
is both powerful, yet easy to use (also for non-experts), and
backwards compatible with the present language.

The resulting design features:

- Traits based, flexible, modern-day, OOP (as in Swift, Rust, Go).
- Traits based, fully type-checked, generics, interoperable with both 
  procedural, functional, and OO programming (as in Swift, Rust, Go).
- *Non-necessity* for explicit instantiation of generics (as in Swift).
- Type sets as traits, to easily formulate generics constraints (as in Go).
- "Zero cost" static polymorphic method dispatch via generics (as in Rust).
- Interoperability with class inheritance, but also support of "sealed" classes.
- Room for future growth, e.g. for future support of array-rank and
  declaration-attribute genericity, structural subtyping, and compile-time
  polymorphic union types.

The example programs are in [`Code/`](Code).
[`Code/README.md`](Code/README.md) compares two implementations of the same
trait for the same type in Fortran, Rust, and Swift (issue #2).

[`most-restrictive-plan.md`](most-restrictive-plan.md) proposes, for
discussion, a restrictive starting point for issue #2: at most one
implementation of a trait for a type in a whole program, declared in the
module that defines the trait or the type. It also discusses ways to relax
these rules.
[`Code/Fortran/globally_unique.f90`](Code/Fortran/globally_unique.f90) is a
small example.
