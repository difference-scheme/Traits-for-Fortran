# Two implementations of one trait for one type

This README covers only the files listed below.

The files explore the example and the questions in issue #2.
[The Fortran example](https://github.com/difference-scheme/Traits-for-Fortran/issues/2#issuecomment-6090276335)
asks how a compiler could choose between two implementations of `IPrintable`
for `real(real64)` if the clients did not `use` the implementing modules.
[The reply](https://github.com/difference-scheme/Traits-for-Fortran/issues/2#issuecomment-6097292972)
asks for Swift (with modules) and Rust versions, and notes that in Rust a client
should only need to import the trait, not the implementation.

Two cases have to be kept apart:

- **One implementation** of a trait for a type. Rust does let a client use it
  by importing only the trait (`Rust/single_impl.rs`).
- **Two implementations of the same trait for the same type**, as in the
  Fortran example. Rust rejects them, whatever the clients import
  (`Rust/two_impls.rs`). The tested Swift build (6.2.3) accepted them from
  separately compiled modules, but Swift does not support the resulting
  program (`Swift/two_impls/`).

These examples are an investigation. They neither change nor decide the design
described in `traits.tex`.

[`../most-restrictive-plan.md`](../most-restrictive-plan.md) proposes one set
of rules for discussion: as in Rust, at most one implementation of a trait for
a type in a whole program, declared in the module that defines the trait or
the type. Under that plan, `Fortran/two_impls_single.f90` is an error, and
`Fortran/globally_unique.f90` is the counterpart that the plan allows. The plan
is not implemented, and the files here add no checks: the LFortran build used
below accepts `two_impls_single.f90`.

## Files

| File | Content | Expected result |
| --- | --- | --- |
| `Fortran/two_impls_single.f90` | The example from the issue comment, verbatim. Each internal procedure `use`s one provider module. | Runs, with an LFortran build that has the experimental traits extension |
| `Fortran/globally_unique.f90` | Counterpart under the most restrictive plan. The only implementation of `IPrintable` for `real(real64)` is in `printable_m`, which defines the trait. The fancy output is the implementation for a wrapper type `FancyReal`, in the module that defines that type. The program imports only `IPrintable` and `FancyReal`, with `ONLY`. | Proposal syntax. The tested LFortran build rejects `call y%output()`; it runs once the program's `ONLY` list for `printable_m` is removed (see below) |
| `Rust/single_impl.rs` | One impl of `IPrintable` for `f64`, in a module the client never names. The client imports only the trait. | Compiles and runs |
| `Rust/two_impls.rs` | Literal translation: two impls of the same `printable_m::IPrintable` for `f64`. The clients import only the trait. | **Compile error E0119** |
| `Rust/two_impls_wrappers.rs` | One shared trait, implemented by the wrapper types `Plain(f64)` and `Fancy(f64)`. | Compiles and runs |
| `Swift/two_impls/` | Literal translation with real, separately compiled modules `Printable`, `Plain`, `Fancy`, `PlainClient` and `FancyClient`, plus `main.swift` and `run.sh`. | Built and ran with the tested Swift 6.2.3, but contains duplicate conformances, which Swift does not support: **the output is an observation only** |
| `Swift/two_impls/ProtocolOnlyClient.swift` | A client that imports only `Printable` and calls `output()` on a `Double`. | **Compile error** (checked by `run.sh`) |
| `Swift/two_impls_wrappers.swift` | One shared protocol, implemented by the wrapper types `Plain` and `Fancy`. | Compiles and runs |

The Swift files use only the standard library, so they print numbers with
Swift's default formatting (`4.9`) instead of the Fortran edit descriptors.

## Running

Run the commands from the repository root, and write all generated files to a
scratch directory outside the repository (`$B` below; delete it afterwards):

```sh
R=$PWD
B=/path/to/scratch/dir
mkdir -p "$B"
```

### Fortran

LFortran writes `.mod` files and the executable into the current directory, so
run it from `$B`:

```sh
(cd "$B" && lfortran "$R/Code/Fortran/two_impls_single.f90")
```

```text
plain:   4.90
fancy: <<  4.9000E+00>>
```

This needs an LFortran build with the experimental traits extension. The output
above is from a development build (version `0.67.0-177-gd5d833cd86-dirty`),
which also prints a warning to stderr that traits are an experimental LFortran
extension. A build without the extension (`0.67.0-62-gcac628af65`) stops with
`syntax error: Token '::' is unexpected here` at `abstract interface :: IPrintable`.

### Fortran: `globally_unique.f90`

Under the plan in `../most-restrictive-plan.md`, this program prints the same
two lines as `two_impls_single.f90`:

```text
plain:   4.90
fancy: <<  4.9000E+00>>
```

It also needs an LFortran build with the experimental traits extension. The
development build above (`0.67.0-177-gd5d833cd86-dirty`) does not implement
the plan, and rejects the program:

```sh
(cd "$B" && lfortran "$R/Code/Fortran/globally_unique.f90")
```

```text
semantic error: no visible intrinsic trait method 'output' for real(8); use its implementation module
```

The error is reported for `call y%output()`, after the warning about the
experimental extension. In this build, a `use` of `printable_m` without `ONLY`
makes the implementation for `real(real64)` visible, but
`use printable_m, only: IPrintable` does not. With only that change to the
program, the build prints the expected lines:

```sh
sed '/^program /,$ s/use printable_m, only: IPrintable/use printable_m/' \
    Code/Fortran/globally_unique.f90 > "$B/globally_unique_use_all.f90"
(cd "$B" && lfortran globally_unique_use_all.f90)
```

```text
plain:   4.90
fancy: <<  4.9000E+00>>
```

`plain_output` remains private: with `use printable_m`, a direct
`call plain_output(y)` in the program is still rejected
(`semantic error: Function 'plain_output' not found (not user defined nor intrinsic)`).
The implementation for `FancyReal` is found through
`use fancy_real_m, only: FancyReal` in both versions. In scratch checks with
the three program units in separate files, compiled one at a time with
`lfortran -c` in dependency order and then linked, both versions gave the
same results as above. So this build can take the needed information from the
`.mod` files, but it does not check the rules of the plan: it accepts
`two_impls_single.f90`, and it also accepted `f%output()` in a program that
did not import `IPrintable`, which the plan rejects (rule 6).

### Rust

Tested with rustc 1.95.0.

```sh
rustc --edition 2021 Code/Rust/single_impl.rs -o "$B/single_impl" && "$B/single_impl"
```

```text
plain:   4.90
```

```sh
rustc --edition 2021 Code/Rust/two_impls_wrappers.rs -o "$B/two_impls_wrappers" && "$B/two_impls_wrappers"
```

```text
plain:   4.90
fancy: <<    4.9000E0>>
plain:   4.90
fancy: <<    4.9000E0>>
```

`two_impls.rs` must fail, with exactly this error:

```sh
rustc --edition 2021 Code/Rust/two_impls.rs -o "$B/two_impls"
```

```text
error[E0119]: conflicting implementations of trait `IPrintable` for type `f64`
  --> Code/Rust/two_impls.rs:39:5
   |
28 |     impl IPrintable for f64 {
   |     ----------------------- first implementation here
...
39 |     impl IPrintable for f64 {
   |     ^^^^^^^^^^^^^^^^^^^^^^^ conflicting implementation for `f64`
```

### Swift

Tested with Apple Swift 6.2.3 on macOS (arm64); `@retroactive` comes from
SE-0364, implemented in Swift 6.0. `run.sh` compiles each module with a
separate `swiftc` invocation that can only see the `.swiftmodule` files built
before it. It fails unless `ProtocolOnlyClient.swift` is rejected with the
expected diagnostic, and then links `main.swift` with the provider objects in
two orders:

```sh
Code/Swift/two_impls/run.sh "$B/swift"
```

```text
== ProtocolOnlyClient.swift (must be rejected)
rejected as expected: error: value of type 'Double' has no member 'output'

The programs below link two conformances of Double to IPrintable.
Swift does not support that; their output is an observation only.

== two_impls_plain_first
PlainClient, concrete call: plain: 4.9
FancyClient, concrete call: fancy: <<4.9>>
PlainClient, generic call:  plain: 4.9
FancyClient, generic call:  fancy: <<4.9>>
main, dynamic cast:         plain: 4.9

== two_impls_fancy_first
PlainClient, concrete call: plain: 4.9
FancyClient, concrete call: fancy: <<4.9>>
PlainClient, generic call:  plain: 4.9
FancyClient, generic call:  fancy: <<4.9>>
main, dynamic cast:         fancy: <<4.9>>
```

The supported Swift counterpart:

```sh
swiftc Code/Swift/two_impls_wrappers.swift -o "$B/two_impls_wrappers_swift" && "$B/two_impls_wrappers_swift"
```

```text
plain: 4.9
fancy: <<4.9>>
plain: 4.9
fancy: <<4.9>>
```

## What the examples show

### Fortran

`print_plain` and `print_fancy` each `use` one provider module, and
`x%output()` uses the implementation that this `use` makes accessible. The
selection is made per scope, by an explicit dependency on the provider. Without
such a dependency, nothing in a scope says which of the two implementations is
meant.

Depending explicitly on a provider is not the same as importing its procedure
names. In a scratch check with the same LFortran build, a variant that declared
`plain_output` and `fancy_output` private still printed both lines through the
trait binding `x%output()`, while a client calling `plain_output` directly was
rejected (`semantic error: Function 'plain_output' not found (not user defined nor intrinsic)`).

The two direct calls on a concrete `real(real64)` do not settle the semantics
of generic code or trait values. A design with scoped implementations has to
carry the selected implementation along when a trait value is constructed or
forwarded, or when a generic procedure is instantiated, instead of
rediscovering it later from the raw type alone. (In the unsupported Swift
program below, the dynamic cast, which has only the type to go on, got
whichever implementation came first in link order.) This is an obligation for
such a design, not a statement about what the current prototype does.

### Rust: global coherence

- A `use` declaration "creates one or more local name bindings"
  ([Reference: use declarations](https://doc.rust-lang.org/reference/items/use-declarations.html)).
  An impl has no name, so it cannot be imported, and no `use` can select one
  impl over another.
- A method call looks for methods "provided by a visible trait implemented by
  `T`"
  ([Reference: method-call expressions](https://doc.rust-lang.org/reference/expressions/method-call-expr.html)).
  The trait must be in scope; the impl is whichever impl of that trait exists
  for `T`.
- [Coherence](https://doc.rust-lang.org/reference/items/implementations.html#trait-implementation-coherence)
  rejects overlapping impls, so there is at most one impl of `IPrintable` for
  `f64` in the whole crate graph. That is why importing only the trait is
  enough in `single_impl.rs`: there is nothing to choose. It is also why
  `two_impls.rs` fails at the impl definitions, although no client names
  `plain_m` or `fancy_m`.
- The [orphan rule](https://doc.rust-lang.org/reference/items/implementations.html#orphan-rules)
  allows an impl only if the trait or at least one of the types in the impl is
  defined in the current crate.
  As separate crates depending on a crate `printable`, `plain_m` and `fancy_m`
  would each be rejected on their own with
  `error[E0117]: only traits defined in the current crate can be implemented for primitive types`
  (checked with rustc 1.95.0). Conversely, for a foreign type such as `f64`, the
  one permitted impl lives in the crate that defines the trait, so every client
  that can name the trait already depends on that crate and its metadata,
  impls included. Within a crate, which is compiled as a whole, the impl may
  sit in any module, as in `single_impl.rs`.
- Using both implementations in Rust means changing the example. Either use
  wrapper types (`two_impls_wrappers.rs`): there is still one shared trait,
  but `f64` itself no longer implements it. Or use two distinct traits, such
  as `PlainPrintable` and `FancyPrintable`: then importing a trait does select
  an implementation, but there is no shared trait for generic code to require,
  and a scope that imports both gets
  `error[E0034]: multiple applicable items in scope` for `x.output()`.

### Swift: global conformances, import-scoped extension members

- The Swift book states: "In Swift, as in Objective-C, protocol conformance is
  global — it isn't possible for a type to conform to a protocol in two
  different ways within the same program"
  ([Access Control: Protocol Conformance](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/#Protocol-Conformance)).
- [SE-0364](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0364-retroactive-conformance-warning.md)
  explains that "protocol conformances are globally unique within a process"
  and that, with duplicates, "it is indeterminate which definition of this
  conformance will 'win'". It added a warning for conformances of an imported
  type to an imported protocol. Without the attribute, Swift 6.2.3 reports for
  `Plain.swift`: `extension declares a conformance of imported type 'Double' to imported protocol 'IPrintable'; this will not behave correctly if the owners of 'Swift' introduce this conformance in the future`.
  `@retroactive` acknowledges and silences that warning. It does not make a
  conformance local to a module, and it does not make two different
  conformances legal. SE-0364 also lists extensions of external types that add
  no conformance as safe, because the module name is part of their symbols.
- Nothing in this build detects the conflict. `Plain` and `Fancy` compile
  cleanly on their own, and the combined program links because their witness
  tables are different symbols
  (`protocol witness table for Swift.Double : Printable.IPrintable in Plain`,
  and `... in Fancy`).
- Observed with `run.sh` (unsupported program, not guaranteed behaviour):
  calls compiled in `PlainClient` used Plain's implementation, and calls
  compiled in `FancyClient` used Fancy's, both for the concrete call and
  through the generic `show`, in both link orders. The dynamic cast
  `(y as Any) as? any IPrintable` in `main.swift`, which names neither
  provider, used whichever provider object came first on the link line. Other
  toolchains, platforms or dynamic libraries may behave differently.
- Extension members are found through imports, not through linking.
  `ProtocolOnlyClient.swift` is rejected although `Plain.swiftmodule` is on the
  search path (`-I`) and `Plain.o` is linked, because neither its imports nor
  their dependencies include module `Plain`. The import need not be direct,
  though: a client may load the dependencies of the modules it imports
  ([SE-0409](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md)),
  and members of transitively imported modules are visible
  ([SE-0444](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md)
  calls this "leaky"). In a scratch check, a file importing only `PlainClient`
  could call `y.output()`. With `-enable-upcoming-feature MemberImportVisibility`
  it was rejected: `instance method 'output()' is not available due to missing import of defining module 'Plain'`.
  Under SE-0444, a member is visible if its module is imported directly or is
  re-exported by a directly imported module. SE-0444 changes only member
  lookup: it does not select between duplicate conformances, and its Future
  directions section leaves the visibility rules for retroactive conformances
  unspecified.
- Further scratch checks of files that see both providers (unsupported,
  observations only): importing `Plain` and `Fancy` directly makes `y.output()`
  an error (`ambiguous use of 'output()'`), but `show(y)` and
  `let p: any IPrintable = y` compiled without any diagnostic and used the
  conformance selected by the order of the `import` declarations. Importing
  `PlainClient` and `FancyClient` instead, so that both providers are only
  transitively visible, let `y.output()` compile without a diagnostic, again
  selected by import order.
- The supported counterpart, `two_impls_wrappers.swift`, uses wrapper types:
  each conformance is declared for a type that its declaring code owns, and
  `Double` itself does not conform to `IPrintable`.

## Scope versus global coherence

| | Fortran example (LFortran experimental build) | Rust | Swift |
| --- | --- | --- | --- |
| What selects the implementation of `output` for a call | The provider module `use`d in the scope | Nothing to select: the unique impl in the crate graph | Static calls: the extension or conformance visible through imports. Dynamic casts: the process-wide conformance lookup |
| What the client needs | A `use` of the provider module | The trait in scope | For extension members, an import that reaches the provider module; with `MemberImportVisibility`, a direct import of it or of a module that re-exports it. This does not select between duplicate conformances |
| Two implementations of the same trait for the same type | Selected per scope | Rejected (E0119; E0117 across crates) | Not supported. The tested build (Swift 6.2.3) accepted the separately compiled modules; the observed behaviour depended on import order and link order |

- With a single implementation, importing only the trait leaves nothing to
  choose. Rust guarantees this case: coherence permits only one
  implementation, and the orphan rule places it in a crate that every client
  already depends on. Under these rules the two-implementation example is an
  error.
- With two implementations of the same trait for the same type, something
  other than the trait import has to say which one a scope uses: an explicit
  dependency on the provider (as in the Fortran example), a named
  implementation, or a different type (wrappers). Otherwise the compiler has no
  basis for the choice. In the tested Swift build, which accepted the
  unsupported program, the choice depended on import order and link order.

Which rules Fortran should adopt is a design decision for the proposal; these
examples do not make it. [`../most-restrictive-plan.md`](../most-restrictive-plan.md)
describes one candidate, a restrictive starting point, and ways to relax it.
