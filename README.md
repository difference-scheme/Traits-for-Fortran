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

- Traits based, flexible, modern-day, OOP (as in Swift, Rust, Go)
- Traits based, fully type-checked, generics, interoperable with both 
  procedural, functional, and OO programming (as in Swift, Rust, Go)
- *Non-necessity* for explicit instantiation of generics (as in Swift)
- Type sets as traits, to easily formulate generics constraints (as in Go)
- "Zero cost" static polymorphic method dispatch via generics (as in Rust)
- Interoperability with class inheritance, but also support of "sealed" classes
- Room for future growth, e.g. for future support of array-rank-genericity,
  or compile-time polymorphic union types
