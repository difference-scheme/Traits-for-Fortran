# Most restrictive plan: globally unique, module-owned trait implementations

This document is a proposal for discussion in
[issue #2](https://github.com/difference-scheme/Traits-for-Fortran/issues/2).
It describes a deliberately strict, Rust-like starting point for two
questions: where may a trait implementation be declared, and how does a
client find it? It then lists ways to relax the restrictions. It is not part
of `traits.tex`, and neither `traits.tex` nor the experimental LFortran
prototype implements these rules. The code uses the syntax proposed in
`traits.tex`, which is not standard Fortran. Where this document would need
further syntax, it leaves the spelling open.

## Background

- Issue #2 settled on explicit module dependencies instead of discovering
  implementations in otherwise unused modules
  ([comment](https://github.com/difference-scheme/Traits-for-Fortran/issues/2#issuecomment-6087519036)).
  It then made this precise: a client may have to import the trait
  (`IPrintable`), but should not have to import the implementing procedure
  ([comment](https://github.com/difference-scheme/Traits-for-Fortran/issues/2#issuecomment-6089672348)).
- [A later comment](https://github.com/difference-scheme/Traits-for-Fortran/issues/2#issuecomment-6090276335)
  declares two implementations of the same `IPrintable` for `real(real64)`, in
  modules `plain_m` and `fancy_m`, and asks how a client that does not `use`
  either module could choose between them. The program is
  [`Code/Fortran/two_impls_single.f90`](Code/Fortran/two_impls_single.f90).
- [The reply](https://github.com/difference-scheme/Traits-for-Fortran/issues/2#issuecomment-6097292972)
  names Rust as the reference for an explicit design, in which only the trait
  needs to be imported.

[`Code/README.md`](Code/README.md) describes the Rust and Swift experiments.
In short, Rust can let a client import only the trait because of two rules.
Coherence allows at most one implementation of a trait for a type in the
whole program, so there is nothing to choose. The orphan rule places that
implementation in a crate that defines the trait or the type, and every
client that can name both already depends on that crate. Rust rejects the
two-implementation program.

This plan carries both rules over to Fortran, in their most restrictive form.
It develops alternative 4 of the issue description ("Restrict where
conformances may be declared"). The issue notes that such a restriction does
not by itself solve discovery; rule 4 below shows how the two fit together.
Starting strict is deliberate: rules can be relaxed later, with a
compatibility analysis for each relaxation, whereas tightening a rule later
would reject programs that used to be valid.

## Summary of the rules

A *conformance* (T, P) is the declaration that type T implements trait P,
either by an `implements P :: T` statement or by an `implements(P)` attribute
in the definition of T.

1. The unit of ownership is a single module.
2. A conformance (T, P) may only be declared in the module that defines P or
   in the module that defines the derived type T. For an intrinsic type T,
   only the module that defines P qualifies.
3. Every conformance is declared in the specification part of the owning
   module, and the compiler records it in the module's exported interface
   metadata (its `.mod` file). This metadata does not change which names are
   PUBLIC: private traits, types and implementing procedures stay private.
   Procedure bodies may be in submodules.
4. A client finds conformances only through its ordinary module dependencies.
5. Each pair of a concrete type and a trait has at most one conformance in a
   whole program.
6. A method that a type only gets from a trait can be called with `%` only
   where the trait is accessible, or through a generic constraint. Existing
   Fortran bindings and intrinsic behavior do not change.
7. `use m, only: P` is enough, and no implementing procedure is imported.
   Generic code and trait objects use the one conformance.
8. The first version accepts only conformances for exact concrete types.
9. The argument for uniqueness covers intrinsic types and nominal derived
   types defined in a module. Other kinds of types wait for precise rules.

## The rules in detail

### Rule 1: the unit of ownership is a module

A trait is owned by the module in whose specification part it is defined
(`abstract interface :: P`). A derived type is owned by the module in whose
specification part its definition appears.

This unit is deliberately narrower than a Rust crate. It is not a file, a
directory, a library, or an implicit package: these can be split or merged
without changing the meaning of a program, and issue #2 already asks that
splitting or combining files must not change which operations are available.
A module, by contrast, has a name that identifies it uniquely in a program
(Fortran 2018 draft, 19.2; see References), and clients see its public
interface only through `USE` (14.2.2).

Use association, renaming and re-export give access to a trait or a type,
but neither ownership nor a new identity. After
`use printable_m, only: Printable => IPrintable`, the name `Printable` still
denotes the trait defined in `printable_m`, and a facade module that
re-exports `IPrintable` does not own it.

### Rule 2: where a conformance may be declared

`implements P :: T` is allowed only in the module that defines P or, if T is
a derived type, in the module that defines T. The `implements(P)` attribute
is part of the definition of T, so it always satisfies this rule.

An intrinsic type has no module that defines it. `real64` from
`iso_fortran_env` is a named constant for a kind value: importing it does
not make the importing module, or `iso_fortran_env`, the owner of
`real(real64)`. A conformance of an intrinsic type can therefore only be
declared in the trait's module. (For traits predefined in an intrinsic
module, as `traits.tex` suggests, only the processor could then provide
conformances of intrinsic types.)

The rule keeps the two central use cases of Rust's rules:

- a new trait, implemented for existing types that the module does not own,
  including intrinsic types: `printable_m` implements its own `IPrintable`
  for `real(real64)`;
- an existing trait, implemented for a new type: `fancy_real_m` implements
  the imported `IPrintable` for its own type `FancyReal`.

It rejects adapter modules that own neither the trait nor the type, even if
no other conformance for the pair exists. In `two_impls_single.f90`,
`plain_m` and `fancy_m` are each rejected on their own, not because there
are two of them: each declares a conformance of the intrinsic type
`real(real64)` to `IPrintable`, which `printable_m` defines. The check is
local to the module being compiled, so whether a module is valid does not
depend on which other modules are in the program.

A stricter variant would allow conformances only in the trait's module. It
would prevent a new type such as `FancyReal` from implementing a trait of an
existing library. This plan therefore takes "the trait's or the type's
module" as its restrictive starting point.

Combined and extended traits do not bypass this rule. A combined declaration
such as `implements (P + Q) :: T`, or the attribute `implements(P + Q)`,
declares the two conformances (T, P) and (T, Q), and each is checked
separately against this rule and rule 5. If a trait P extends a trait Q
(`abstract interface, extends(Q) :: P` in `traits.tex`), a conformance
(T, P) requires a valid conformance (T, Q) that is declared on its own, in a
module permitted to declare it (possibly the same module); declaring (T, P)
does not silently create (T, Q) in P's module. If it did, two modules that
own traits P1 and P2, both extending a foreign trait Q, could each create
(T, Q) for a foreign type T without either module depending on the other, so
the cycle that the uniqueness argument relies on would not arise. Code that
requires Q can still use every T that conforms to P, because (T, Q) then
exists. Requiring separately declared conformances for the extended traits is
the conservative, Rust-like choice; further details and syntax are left open.

This plan covers conformances only. Blocks without a trait,
`implements :: T`, only bind procedures to T (`traits.tex`, "Binding
functionality to a type") and would need a matching rule. The restrictive
choice would be to allow them only in the module that defines T, and thus not
at all for intrinsic types.

### Rule 3: conformances are recorded in the owner's module interface

Every conformance is declared in the specification part of its owning
module, never only in a submodule or in a procedure. The compiler records it
in the module's exported compiler interface (the `.mod` file, or its
equivalent), which a compiler needs whenever the module is used, directly or
as a dependency (rule 4). Fortran already requires the public portions of a
module to be available when a `USE` of it is processed (14.2.2); this plan
adds the conformance metadata to what must be available. The metadata
contains or references:

- the identity of the trait (its defining module and name) and the canonical
  identity of the type (rule 5);
- for each member that the trait requires, the binding: the implementing
  procedure as a linkable identity, with its characteristics and
  `pass`/`nopass`;
- what clients need to refer to the one witness table of the conformance,
  which dynamic dispatch through `class(P)` uses.

This is compiler-interface metadata, not language-level accessibility.
Recording a conformance does not make a private trait or type accessible to
clients, and does not require it to be public; the ordinary PUBLIC and
PRIVATE rules continue to apply to all names. In particular, the metadata
does not put the names of the implementing procedures into any client's
namespace. They can be `private`, as `plain_output` and `fancy_output` are in
the example, much as a public type-bound procedure binding in present Fortran
can name a private procedure. Their bodies can be separate module procedures
implemented in submodules.

A submodule cannot add a conformance that its ancestor module's interface
does not declare. Clients are compiled against the ancestor's interface, so
they would not see it. Also, a submodule may use modules that themselves use
the ancestor, which would break the argument for uniqueness below.

### Rule 4: discovery follows explicit module dependencies

When it compiles a scoping unit, the compiler knows the conformances declared
in the modules on which the unit depends: the modules it uses, the modules
that those modules use, and so on, as recorded in their interfaces. A facade
module that re-exports a trait thus also brings in the trait's module.
Nothing else counts: not other `.mod` files on the search path, not other
modules in the same source file or directory, not the objects or libraries on
the link line or their order, and not a project-wide registry. There is no
"first match".

Together with rule 2, this is always enough. Code that involves both a
derived type T and a trait P needs their definitions. So it depends on the
module that defines T and on the module that defines P, and only these two
modules can declare (T, P). For an intrinsic type, only the trait's module
can. The compiler can thus also conclude that T does not implement P when
neither module declares it, without having to worry about modules that it
cannot see.

### Rule 5: one conformance per type and trait

For each canonical concrete pair (T, P) there is at most one conformance in a
whole program. It does not depend on the scope, the import path, `ONLY`
lists, renaming, or when an object was created. All objects of type T share
it, as `traits.tex` already says of added functionality ("Implementing
traits for intrinsic types"). A conformance belongs to the pair; it is not an
entity that clients import or select.

Canonical identity means:

- a trait is identified by its original definition, whatever local name it
  is accessed by;
- a derived type by its definition (see rule 9);
- an intrinsic type by its type and kind value, not by how the kind is
  spelled. If `real64` and `selected_real_kind(15)` have the same value,
  conformances for `real(real64)` and `real(selected_real_kind(15))` are for
  the same type, and two of them in one module are duplicates.

The compiler only needs to look for duplicates within the module that it is
compiling; see "Why the rules give uniqueness".

### Rule 6: calling trait methods

A method that a type gets only from a conformance (a binding in an
`implements P :: T` statement) can be called as `x%output()` only where P is
accessible, by use or host association, or where the type of `x` is a
generic parameter constrained by P. This corresponds to Rust's requirement
that the trait be in scope. The import decides which names are looked up; it
does not decide whether, or how, T implements P.

The rule applies only to these new trait-provided methods. Type-bound
procedures declared in a derived-type definition keep their present meaning,
including bindings that satisfy an `implements(P)` attribute. So do the
intrinsic procedures and operators of intrinsic types. If a type's module
declares a conformance that an existing binding already satisfies, calls of
that binding must not start to require an import of the trait.

If two distinct traits that are accessible in a scope both provide a method
of the same name for T, a call `x%m()` is ambiguous and must be diagnosed,
not resolved by import order. A call that resolves to an ordinary type-bound
procedure today keeps that meaning.

### Rule 7: imports, generic code and trait objects

In the example, `use printable_m, only: IPrintable` gives the program the
name `IPrintable`. Since the program thereby depends on `printable_m`, it
also knows the conformance of `real(real64)` to `IPrintable` declared there,
including the binding to `plain_output`. That procedure is never imported
and remains private.

A generic procedure such as `show{IPrintable :: T}(x)` depends only on its
constraint. A call `call show(y)` is checked where the type of `y` is known,
and by rule 4 the conformance is known there too, even in a scope that
accesses only `show` and not the trait. Since there is only one conformance,
the type determines it, so the identity of an instance of `show` for
`real(real64)` needs no extra parameter for a scope-selected implementation.
Generic code may still pass or store the canonical witness information, for
example as a dictionary argument, and a compiler may still specialize
(monomorphize) it; uniqueness eliminates neither.

A trait object such as `class(IPrintable)` still dispatches dynamically.
Constructing one from a `real(real64)` or `FancyReal` value stores a
reference to the one witness table of the pair, so forwarding the object
never requires a new lookup. Uniqueness does not remove dynamic dispatch, and
it does not require clients to import implementation bodies.

### Rule 8: first version, exact concrete implementations only

The first version accepts conformances only for one concrete type at a time:
an intrinsic type with a given kind, or a nominal derived type that has no
type parameters and is not generic. It has no blanket implementations (one
declaration for every type that satisfies some constraint), no conditional
implementations (such as a container that implements `IPrintable` whenever
its element type does), no declarations for all instances of a generic type,
no specialization, and no overlapping implementations.

This does not restrict generic procedures and methods constrained by traits,
such as `sum{INumeric :: T}` in `Code/Fortran/ocp.f90`.

### Rule 9: which types the argument covers

The argument for uniqueness below needs each conformance target to have at
most one owning module. This holds for intrinsic types, which have none. It
also holds for derived types that are defined in a module and have neither
the SEQUENCE nor the BIND attribute. By 7.5.2.4 of the Fortran 2018 draft,
entities declared with reference to different definitions of such types are
of different types, so each such type has exactly one definition and one
defining module.

For SEQUENCE and BIND(C) types, 7.5.2.4 lets separate definitions describe
the same type: they need the same type name, no private components, and
components that agree in order, name and attributes. Two modules could then
each define such a type and each declare a conformance for it as its owner,
without either module depending on the other. The baseline therefore does
not accept SEQUENCE or BIND(C) types as conformance targets. This restricts
where conformances can be declared; it does not change Fortran's rules for
type equality.

The baseline also excludes, until precise rules exist:

- parameterized derived types, and generic types such as `Vector{U}`;
- conformances inferred through type extension, such as an extension type
  inheriting its parent's conformance (`traits.tex`, "Use with the abstract
  attribute"), and their meaning for `class(T)` entities;
- matching that depends on length type parameters (including character
  length) or on rank;
- traits and types defined outside the specification part of a module, which
  have no owning module.

## Why the rules give uniqueness

Let T be a derived type covered by rule 9, defined in module A, and let P be
a trait defined in module B. Suppose the program contains two conformances
(T, P).

- If both are declared in the same module, the compiler sees both while
  compiling that module and rejects the second.
- Otherwise, by rule 2, one is declared in A and the other in B, and A is
  not B. The declaration in A names P, so A uses B, directly or indirectly.
  The declaration in B names T, so B uses A. Then A references itself
  indirectly, which Fortran does not allow (14.2.2). So this case cannot
  occur.

For an intrinsic type, only B can declare (T, P), so only the first case
applies.

The argument relies on:

- every conformance being declared in a module's specification part, and so
  recorded in its interface (rule 3). A submodule of A may use B even when B
  uses A, so a conformance declared in that submodule would escape the cycle;
- one defining module per type (rule 9), and one module per module name in a
  program (19.2);
- consistent artifacts: all `.mod` files and objects in a program come from
  the same version of each module. The rules do not make stale or mismatched
  artifacts work. An implementation could, for instance, record a
  fingerprint of each module's conformances to detect such mismatches.

Rule 4 adds that any module permitted to declare (T, P), that is, the module
that defines T or the module that defines P, is a dependency of every scoping
unit that involves both T and P. In general both modules are eligible, but in
a valid program at most one of them actually declares the conformance.

## Example

[`Code/Fortran/globally_unique.f90`](Code/Fortran/globally_unique.f90) is the
counterpart of `two_impls_single.f90`:

- `printable_m` defines `IPrintable` and declares the only implementation for
  `real(real64)` (plain format), with the private procedure `plain_output`;
- `fancy_real_m` defines the sealed wrapper type `FancyReal` and declares its
  implementation of `IPrintable` (fancy format), with the private procedure
  `fancy_output`. This is a conformance of another type, not a second one
  for `real(real64)`;
- the program imports `IPrintable` and `FancyReal` with `ONLY`, and calls
  `y%output()` and `f%output()`.

Under this plan, the program prints

```text
plain:   4.90
fancy: <<  4.9000E+00>>
```

The experimental LFortran prototype does not implement this plan. It
accepts `two_impls_single.f90`. In a scratch check, it rejected
`call y%output()` in `globally_unique.f90` with the import
`use printable_m, only: IPrintable`, and accepted the program once that
`ONLY` list was removed. [`Code/README.md`](Code/README.md) gives the
commands and their output.

Instead of a wrapper type, one could define two distinct traits, say
`IPlainPrintable` and `IFancyPrintable`, each implemented for `real(real64)`
in its own module. Then there is no single trait for generic code to
require, and a scope in which both traits are accessible gets an ambiguity
diagnostic for `y%output()` (rule 6), as Rust does with E0034 (see
`Code/README.md`).

## Consequences for the existing examples

None of the existing examples is changed by this proposal. Under this plan:

| Example | Consequence |
| --- | --- |
| `Code/Fortran/two_impls_single.f90` | Rejected: `plain_m` and `fancy_m` each declare a conformance for a trait and a type that they do not define. |
| `Code/Fortran/printy.f90` | The conformance is allowed, because `real64_module` defines `IPrintable`. To call `y%output()`, the program has to make the trait accessible, for example with `use real64_module, only: IPrintable`. |
| `Code/Fortran/ocp.f90` | The empty `implements INumeric` statements for `integer` and `real(real64)` in module `intrinsics` have to move into `interfaces`, which defines `INumeric`. No program unit uses `intrinsics` today, so rule 4 would not find them there anyway, whereas the program and all libraries use `interfaces`. The `ISum` conformances of `SimpleSum` and `PairwiseSum`, and the `IAverager` conformance of `Averager`, are declared in the modules that define these types, and stay. |
| `Code/Fortran/overloading.f90` | The conformance of `real` to `IReducible + IPrintable` has to move from `real_type`, which no program unit uses, into `basic_interfaces`. The conformance of `MyType`, in its own module `my_type`, stays. |
| `Code/Fortran/static.f90`, `Code/Fortran/vector.f90` | The conformances of the generic types `PairwiseSum{U}`, `Averager{U}` and `Vector{U}` are in the modules that define these types, but each covers all instances of a generic type. The first version does not accept them (rule 8; see relaxation 3). |

Traits defined by type sets, such as `INumeric` in `mixed.f90` and
`static.f90`, need no `implements` declarations: their member types are
listed in the trait itself.

`ocp.f90` also shows the cost of choosing a single module as the unit of
ownership. `traits.tex` points out that the Rust version could accept a
further intrinsic type through a new module implementing `INumeric`, without
changes to existing code. In Rust, such a module can be anywhere in the crate
that defines the trait. Under this plan, a new derived type can still
implement `INumeric` in its own module, but a further intrinsic type needs
its conformance added to `interfaces` itself. Relaxation 2 would allow a
separate module again.

## What the plan gives up

Relative to `traits.tex` as it stands:

- implementations that "could then have been distributed even among
  different modules and files" (Sect. "Split implementation") are limited to
  the trait's and the type's modules;
- acknowledging a conformance from a third module, like `module enhanced` in
  Sect. "Retroactive implementation", requires that module to define the
  traits;
- importing a kind constant such as `real64`, or a type's definition, is no
  longer enough to call methods that the type gets from a trait (Sect.
  "Implementing traits for intrinsic types"). The client must depend on the
  module that declares the conformance, and the trait must be accessible for
  `%` calls.

A module that owns neither a trait nor a type cannot connect the two. Its
options are a wrapper type (like `FancyReal`), a new trait of its own (which
it may implement for foreign and intrinsic types), or asking the owner of
the trait or of the type to add the conformance.

## Relaxations

Some things are already allowed by the baseline and need no relaxation:
facade modules that re-export traits and types, renaming, private
implementing procedures, and procedure bodies in submodules (as long as the
conformance itself is declared in the module).

The relaxations are listed in order of increasing risk. The goal for each is
to keep the meaning of baseline code whose declarations and dependencies do
not change. Whether a relaxation meets that goal needs its own compatibility
analysis, and code that uses a relaxation to add implementations or
dependencies can break existing clients in the ways described under
"Compatibility" below. All of the relaxations keep rule 5: one conformance per
pair in a program.

### Relaxation 1: trait-qualified method calls

A call syntax that names the trait along with the method would let a scope
call either of two methods of the same name from two accessible traits. It
would also reach a trait method that an ordinary type-bound procedure of the
same name hides. It does not change which conformances exist, since the
syntax names a trait, never an implementation. To be specified: the spelling
(this document assumes no existing syntax), how it applies to operators,
initializers and `nopass` procedures, and that the trait must be accessible.

### Relaxation 2: larger, explicit ownership units

An explicitly declared group of modules, comparable to a Rust crate, could
be the unit of ownership. `ocp.f90` could then keep its separate `intrinsics`
module. But the module-cycle argument does not survive merely allowing
conformances in arbitrary sibling modules. Two siblings can declare the same
pair without depending on each other. Two groups can also declare (T, P) from
both sides without a module cycle: a module of group A uses the trait module
of group B, and a module of group B uses the type module of group A. Such a
design needs:

- a defined boundary: which modules form a unit, declared explicitly and not
  inferred from files or directories;
- a check for duplicate conformances across the whole unit;
- complete exported conformance metadata: a client of any module of the unit
  must see every conformance of the unit that it could involve;
- acyclic dependencies between units, or an equivalent coherence check;
- rebuild rules, because adding a conformance anywhere in a unit changes the
  metadata that the clients of the unit were compiled against.

Letting a submodule declare a conformance is the same problem on a smaller
scale: the declaration has to be registered in the ancestor module's
interface before clients are compiled against it. Linking an extra submodule
object is not enough.

### Relaxation 3: type families, generic and conditional implementations

This would allow one declaration for all instances of a generic type (as
`static.f90` and `vector.f90` need), conditional implementations, and
eventually blanket implementations. To be specified:

- who owns a declaration for a family of types. If only the module that
  defines the generic type itself, or the trait's module, may declare it,
  the cycle argument still puts all declarations for one generic type and
  one trait into one module. If a type that only appears as a parameter, as
  in `Vector{FancyReal}`, could confer ownership, unrelated modules could
  declare overlapping implementations (for instance for a type with two
  parameters) without either module seeing the other. That needs further
  restrictions;
- a conservative overlap check: two declarations overlap if some concrete
  pair matches both, and overlapping declarations stay rejected. The check
  should not rely on a type not implementing some trait, because an owner
  can add that conformance later;
- how type parameters, including kind and length parameters, take part in
  matching.

A declaration in a generic type's own module that covers all instances
without further conditions is the natural first step. Blanket
implementations are the riskiest part, since a declaration for every type
that satisfies a constraint can overlap with any other conformance of the
same trait. Specialization, where a more specific implementation overrides a
general one, is not a small follow-up: it changes both how an implementation
is selected and how overlap is checked, and it needs its own coherent model.
This document proposes no syntax for any of this.

### Relaxation 4: controlled external adapters

Permitting independent adapter modules that own neither the trait nor the
type would remove the ownership-based guarantee of uniqueness. Two possible
approaches to preserve that guarantee are:

- Delegation: the owner of the trait or of the type records in its interface
  metadata that (T, P) exists and is provided by a named adapter module.
  Clients that depend on the owner then see the canonical declaration. The
  costs: the owner has to change its interface and be rebuilt to add the
  record, so this is not unrestricted retroactive conformance; the record
  becomes part of the owner's API; and the adapter becomes an explicit
  dependency of the owner's clients, recorded in the owner's metadata and in
  the build and link inputs. How that dependency is expressed has to be
  designed: clients need the adapter's metadata, or at least the identities
  of its procedures, and programs must link the adapter.
- Explicit build-time selection: a separately designed model, in which a
  program states for each such pair which adapter it uses, and the build
  rejects a second one. Libraries compiled before that choice could not rely
  on the conformance.

Unrestricted orphan modules combined with trait-only imports are not
justified. A client that imports only the trait does not depend on the
orphan module, so it cannot find it (the original question of issue #2), and
the local ownership checks no longer ensure uniqueness. An additional
mechanism, such as a whole-program duplicate check, would be needed.

### Not relaxations: different designs

The following are not relaxations of this plan, for different reasons:

- Several scope-selected implementations of the same pair (selected by
  `use`, as the current prototype does for `two_impls_single.f90`) violate
  rule 5. They need a different design, in which the selected implementation
  is carried through generic instances and trait objects, and in which two
  values of the same type can behave differently.
- Implicit discovery of providers, that is, finding a conformance in a module
  that the client does not depend on (through search paths, a project-wide
  registry or whole-program analysis), does not necessarily violate global
  uniqueness: such a system could still reject duplicates across the whole
  program. It violates rule 4 instead, and it changes the separate-compilation
  model, in which a scoping unit is compiled from the interfaces of the
  modules it depends on. That is the reason to exclude it.
- Selecting one of several conflicting implementations by import order or
  link order is not a coherence check at all: it accepts the conflict and
  resolves it arbitrarily.

They stay excluded. Specialization, too, needs its own coherent model, as
noted above.

### Extending the covered types

The boundaries of rule 9 can be extended one at a time, each with a precise
rule. For SEQUENCE and BIND(C) types, a natural option is to allow only
conformances declared in the trait's module. The trait has one owner, so the
question of which module owns the type does not arise. Matching must then
follow Fortran's type equality (7.5.2.4), though: declarations in the
trait's module for two definitions that describe the same type are
duplicates, and a client that has its own definition of the same type gets
the same conformance. This is a future option, not part of the first
version.

## Compatibility

Even with one conformance per pair, changes to conformances can break
clients:

- adding a conformance can make a call ambiguous in a scope where another
  trait with a method of the same name is accessible (rule 6);
- with relaxation 3, adding a family or blanket declaration can conflict with
  conformances that clients have declared for their own types;
- removing a conformance breaks every client that relies on it.

Such changes are API changes of the declaring module, and no relaxation makes
them automatically compatible.

## Recommended path

1. Adopt rules 1 to 9 as the baseline, with rule 5 as a permanent invariant.
2. Add relaxations only when real code needs them, roughly in the order
   above, each with a precise specification.
3. Keep scoped implementations, order-based selection and implicit discovery
   out of the design.

## References

- Fortran 2018 draft standard (public), J3/18-007r1,
  <https://j3-fortran.org/doc/year/18/18-007r1.pdf>: 7.5.2.4 (Determination
  of derived types), 14.2.2 (The USE statement and use association), 19.2
  (Global identifiers).
- The Rust Reference:
  [trait implementation coherence](https://doc.rust-lang.org/reference/items/implementations.html#trait-implementation-coherence)
  and
  [orphan rules](https://doc.rust-lang.org/reference/items/implementations.html#orphan-rules).
- [`Code/README.md`](Code/README.md): the Fortran, Rust and Swift experiments
  for issue #2.
