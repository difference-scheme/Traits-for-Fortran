# Traits extension: overloaded generic procedures and initializer reflection

*A proposed extension to the Fortran traits proposal, motivated by
dependency injection. Draft for review; nothing described here is
implemented yet. This version incorporates the review
[traits-di-review.md](traits-di-review.md) and the authors'
[answers](traits-di-review-answers.md) to it.*

## 1. Introduction

The traits proposal enables plugin architectures, in which code depends
only on traits (polymorphic interfaces) and never on the types that
implement them. In such an architecture no dependency is hardwired. The
association of each trait to the implementing type that an application
actually wants to use must instead be *softwired* at run time. The
standard technique for doing so is Dependency Injection (DI): objects of
implementing types are injected into the initializers (constructors) of
other types, which themselves depend merely on traits.

For small applications this can be done manually:

```fortran
cobj = Client(DoubleLogger(Printer(), Writer()))
```

For large applications, with hundreds of implementing types, manual
injection becomes cumbersome, and a *DI container* is used instead. The
types are registered with the container once, and the container then
resolves the whole object graph recursively, starting at the top-level
trait:

```fortran
call cont%register(...)          ! once per trait
cobj = cont%resolve(...)         ! builds Client, DoubleLogger, Printer, Writer
```

### 1.1 The problem: hand-written factory functions

With the traits proposal as it stands, such a container can be written,
but it has to be fed one hand-written *factory function* per
implementing type. Here is the factory of `DoubleLogger` from the
present Fortran container
([FortranDIContainer](https://github.com/difference-scheme/FortranDIContainer)):

```fortran
function create_DoubleLogger(c) result(res)
   class(IResolver), intent(in)  :: c
   class(*),         allocatable :: res
   class(IPrinter),  allocatable :: arg1
   class(IWriter),   allocatable :: arg2

   select type( obj => c%resolve("IPrinter") )
   class is (IPrinter)
      arg1 = obj
   end select

   select type( obj => c%resolve("IWriter") )
   class is (IWriter)
      arg2 = obj
   end select

   res = DoubleLogger(arg1,arg2)
end function create_DoubleLogger
```

Every such function follows the same mechanical recipe. It looks up each
argument of the type's initializer by the *name of the argument's
trait*, downcasts the result with `select type`, and calls the
initializer. The registration then pairs a string with the function:

```fortran
call cont%register("ILogger", create_DoubleLogger)
```

Nothing ties the string `"ILogger"` to the trait `ILogger`, or the
factory's result to that trait. A typo, or registering a type under the
wrong trait, is only discovered at run time, if at all.

In a recently ported CFD code there are 59 such functions, one for every
derived type, each with one or more `select type` statements. All of
them are boilerplate that the compiler could write, because everything
it needs is already known at compile time: the initializer's argument
traits and its result type.

### 1.2 The goal

Swift's version of the same container
([DIContainer](https://github.com/difference-scheme/DIContainer)) has
no factory functions at all. The compiler generates them, using two
language features:
- **Overloading of generic functions and initializers;**
- **A small amount of reflection:**
  - meta-types;
  - initializers usable as function values;
  - type inference through function-typed arguments.

This document:
- analyzes how the Swift container works (Sect. 2);
- proposes the minimal set of Fortran extensions that achieves the same
  (Sect. 3);
- shows the complete ported container (Sect. 4);
- closes with restrictions, the decisions taken in review, and an
  outlook (Sects. 5–6).

The end result for the user is:

```fortran
cont = Container()

call cont%register{IClient}(Client)
call cont%register{ILogger}(DoubleLogger)
call cont%register{IPrinter}(Printer)
call cont%register{IWriter}(Writer)

cobj = cont%resolve{IClient}()
call cobj%log()
```

With these extensions:
- **No factory functions:** they are gone.
- **No strings:** the user writes no strings and no `select type`.
- **Compile-time errors** catch:
  - registering a type under a trait it does not implement;
  - registering a type whose initializer the container cannot call.
- **Loose coupling:** the container's code depends only on traits, and
  on the one concrete `Factory` type, exactly as the Swift container
  does.

## 2. How it works in Swift

The reference is the closure-less version of the Swift container, in
the
[`noclosure`](https://github.com/difference-scheme/DIContainer/tree/noclosure)
branch of DIContainer. It replaces the closures of the original by
objects, so that it can be compared directly with Fortran.

### 2.1 Usage

The Swift container is used as follows:

```swift
var c = Container()

c.register(IClient.self,  Client.init)
c.register(ILogger.self,  DoubleLogger.init)
c.register(IPrinter.self, Printer.init)
c.register(IWriter.self,  Writer.init)

let client = c.resolve(IClient.self)
client.log()
```

where, for instance, `DoubleLogger` is declared as:

```swift
public struct DoubleLogger: ILogger {
    let printer: IPrinter
    let writer:  IWriter

    public init(_ printer: IPrinter, _ writer: IWriter) {
        self.printer = printer
        self.writer  = writer
    }
    public func log() { ... }
}
```

Notice that `DoubleLogger` contains no DI code at all. It merely declares
what it needs in its initializer, which it would have anyway.

### 2.2 The language features involved

**Meta-types.** `IClient.self` is a value that denotes the protocol
`IClient` itself. Its type is a meta-type, written `P.Type` in generic
code. Passing it as an argument lets the compiler infer a generic
parameter `P` from it. It also serves as the container's key, through
`String(describing: protocolType)`, which yields `"IClient"`.

**Initializers as function values.** `DoubleLogger.init` is a function
value of type `(IPrinter, IWriter) -> DoubleLogger`. Its type carries
the complete information about the initializer: the number of
arguments, their types, and the result type. This is the "reflection"
the container needs.

**Type inference through function-typed arguments.** The container's
`register` is generic:

```swift
public mutating func register<P,T1,U>(_ protocolType: P.Type,
                                      _ ctor: @escaping (T1) -> U)
```

Passing `Client.init`, of type `(ILogger) -> Client`, binds `T1` to
`ILogger` and `U` to `Client`. The compiler does so by unifying the
function type of the actual argument with the function type of the
parameter.

**Overloading of generic functions.** Swift has no variadic generics in
the version used here, so there are three overloads of `register`, for
initializers of zero, one and two arguments:

```swift
func register<P,U>      (_: P.Type, _ ctor: @escaping ()      -> U)
func register<P,T1,U>   (_: P.Type, _ ctor: @escaping (T1)    -> U)
func register<P,T1,T2,U>(_: P.Type, _ ctor: @escaping (T1,T2) -> U)
```

Only the overload whose function type has the right number of
parameters can accept a given initializer, so the call resolves
uniquely.

**Generic, overloaded initializers.** The type-erasing `Factory` has
three generic initializers of its own, again one per arity:

```swift
public struct Factory: IFactory {
    private let box: any IFactory

    public init<U>(_ constructor: @escaping () -> U) {
        box = Factory0(ctor: constructor)
    }
    public init<T1,U>(_ constructor: @escaping (T1) -> U) {
        box = Factory1(ctor: constructor)
    }
    public init<T1,T2,U>(_ constructor: @escaping (T1,T2) -> U) {
        box = Factory2(ctor: constructor)
    }
    ...
}
```

`register` simply writes `Factory(ctor)`, and the overloads of
`Factory.init` pick the right one.

**Inference of a generic type's parameters.** In
`box = Factory1(ctor: constructor)`, the generic struct
`Factory1<T1,U>` is constructed without its type arguments. Swift infers
`T1` and `U` from the type of `constructor`.

**Type erasure through objects.** Each of `Factory0`, `Factory1` and
`Factory2` stores the initializer and resolves its arguments
recursively through the container:

```swift
private struct Factory1<T1,U>: IFactory {
    let ctor: (T1) -> U
    public func create(_ c: any IResolver) -> Any {
        ctor(c.resolve(T1.self))
    }
}
```

All of them conform to `IFactory`, so they can be stored as
`any IFactory` in `Factory`'s `box`. `Factory` conforms to `IFactory`
as well, and the container keeps `Factory` objects in one dictionary
keyed by the protocol name. This *type-erases* the different
initializers.

**Dynamic casts.** `resolve` looks up the factory, calls it, and casts
the `Any` result back with `as? P`. The cast is checked at run time
against the protocol conformance records of the dynamic type:

```swift
public func resolve<P>(_ protocolType: P.Type) -> P {
    let key = String(describing: protocolType)
    guard let instance = factories[key]?.create(self) as? P else {
        fatalError("No registration available for \(protocolType)!")
    }
    return instance
}
```

### 2.3 Swift's overload resolution rules

The Swift type checker treats a call to an overloaded name as a
*disjunction*. Each overload is tried in turn, and its generic
parameters are replaced by fresh type variables ("opened"). The solver
then tries to satisfy all constraints:
- the arguments must convert to the parameter types;
- the type variables must satisfy their generic requirements.

Every overload that yields a solution is *viable*. When more than one is
viable, the solutions are compared:

1. **Score.** Each solution has a score vector, which counts things like
   fixes, implicit conversions (value-to-optional, function conversions)
   and uses of disfavored declarations. The lower score wins.
2. **Ranking.** On equal scores, the overload choices themselves are
   compared:
   - **A non-generic declaration beats a generic one.** This is the
     first check made when exactly one of the two is generic.
   - **The more specialized declaration wins.** Declaration A is more
     specialized than B if A's parameter list could be passed to B but
     not the other way around. The check uses subtyping, after opening
     B's generic parameters.
   - **The more constrained generic wins.** Of two otherwise equal
     generic declarations, the one with stronger requirements wins,
     e.g. `T: Sendable` over unconstrained `T`.
3. **Ambiguity.** If still no solution is better than all others, the
   call is ambiguous and rejected.

Swift rejects only identical redeclarations at the point of
declaration; overlapping overloads are accepted, and ambiguity is
diagnosed only at a call. Its rules are not given in a
formal specification. They live in the type checker's ranking code
(`CSRanking.cpp`) and are described informally in the compiler's
`docs/TypeChecker.md`.

The DI container only needs the simplest case: overloads that differ in
the *arity of a function-typed parameter*. For a given initializer only
one overload is viable, and no ranking is needed at all.

### 2.4 What Swift does at run time

Swift compiles a generic function once, without specializing it. The
type metadata of each type parameter, and the witness table of each
conformance the function needs, are passed to it as hidden arguments.
Specializing a generic function for particular type arguments, as
Fortran does, is an optimization. Swift builds metadata for instances
of generic types lazily at run time, but it never generates code at run
time.

This is why the call `c.resolve(T1.self)` inside `Factory1.create` works
even though `c` is an existential (`IResolver`, a protocol-typed value):
the metadata of `T1` is passed to `resolve` at run time, and `resolve`
is found in `c`'s witness table. Two other things also happen at run
time:
- the `as? P` cast;
- a failed lookup, which is a run-time `fatalError`.

In particular, nothing checks at compile time that
`register(ILogger.self, Printer.init)` registers a type that conforms to
`ILogger`.

## 3. The Fortran design

### 3.1 Overview

The design maps each Swift ingredient to a Fortran counterpart. Most of
the needed machinery already exists in the proposal or in the LFortran
prototype:
- generic procedures and generic derived types;
- type inference;
- initializers;
- trait objects;
- `select type` with `class is (ITrait)`.

What is missing are eleven small extensions, E1–E10 with E8b:

| Swift | Fortran (this proposal) | |
|---|---|---|
| `P.Type`, `IClient.self` | trait parameters `{Trait :: P}`; explicit type argument `register{IClient}(...)` | E1, E5 |
| (runtime check `as? P` only) | conformance constraints between parameters, `{P :: U}` | E2 |
| `DoubleLogger.init` as a value | the type name designates its initializer: `register{ILogger}(DoubleLogger)` | E3 |
| inference from `(T1) -> U` | generic abstract interfaces, and inference through dummy procedures | E4 |
| `register<P,U>`, `register<P,T1,U>`, ... overloads | overloading of generic procedures | E6 |
| `String(describing: P.self)` | intrinsic `type_name{P}()` | E7 |
| `init<T1,U>(...)` of `Factory` | generic initializers | E8 |
| `Factory1(ctor: constructor)` | inference of a generic type's parameters in constructor references | E8b |
| `init<U>`, `init<T1,U>`, ... overloads | overloading of generic initializers | E9 |
| `c.resolve(T1.self)` on an existential `c` | generic messages with trait parameters, called through trait objects | E10 |
| `Factory0<U>: IFactory`, `any IFactory` | generic derived types implementing an `IFactory` trait, stored as trait objects | (existing) |
| `as? P` | `select type ... class is (P)` | (existing) |

Two Swift features are deliberately *not* adopted:
- **Escaping closures.** Fortran has no closures that outlive their
  host. A closure is an object with one method, and the proposal
  already has objects with methods. The Swift container itself can do
  without closures, as its `noclosure` version shows, and the Fortran
  design follows that version.
- **Meta-type values.** Fortran's generics are instantiated statically,
  and the proposal already has a syntax for passing types to generic
  procedures: explicit type arguments in curly braces. A type or trait
  passed in braces plays the role of Swift's `IClient.self`. A
  first-class meta-type *value*, storable in variables, would be a much
  larger addition, and is not needed here.

### 3.2 E1: Trait parameters

A generic type parameter may range over *traits*, not only over types.
It is declared with the predefined meta-trait `Trait`:

```fortran
function resolve{Trait :: P}(self) result(res)
   type(itself), pass, intent(in) :: self
   class(P),           allocatable :: res
end function resolve
```

The corresponding type argument must be a trait:
`c%resolve{IClient}()`. A trait combination such as `IA + IB` is also
allowed. Inside the generic, a trait parameter `P` may be used wherever
a trait name may be used:
- in `class(P)` declarations of trait objects;
- in `select type` guards `class is (P)`;
- as the constraint of another type parameter (E2);
- as a type argument of other generics;
- in `type_name{P}()` (E7).

It may not be used in `type(P)`: a trait is not a type.

Where a trait argument is known at compile time, an instance such as
`resolve{IClient}` is ordinary code in which `P` has been replaced by
`IClient`. Its `class is (IClient)` guard is the existing run-time
conformance query, so the run-time machinery is the existing one. E10
covers the calls through trait objects, where the trait argument is not
known when the called code is compiled.

**The predefined names `Trait` and `AnyType`.** `Trait` is the
meta-trait that every trait satisfies. The empty trait of the main
proposal, which every type satisfies, is renamed from `IAnyType` to
`AnyType`. Neither name carries a prefix: the main proposal's `I`
prefix for traits is a convention that is left to the user, as Fortran
leaves all naming conventions to the user. Both names follow the rules
of Fortran's intrinsic type names:
- **Always available.** They are accessible in every scoping unit,
  without a `use` statement, like `integer` or `real`.
- **Not reserved.** Fortran has no reserved words. An entity other than
  a derived type or trait, such as a variable or a procedure, may be
  named `Trait` or `AnyType`. Where a generic parameter list expects a
  constraint, before `::`, the name always denotes the predefined
  meta-trait or trait. The parser decides by context, as it does for
  intrinsic type names.
- **Not usable for a derived type or trait.** As a derived type may not
  be named after an intrinsic type (F2023 7.5.2.1), a derived type or a
  trait may not be named `Trait` or `AnyType`.

For intrinsic type names this gives, for example:

```fortran
program test
   integer :: real = 1     ! a variable named real
   real    :: x            ! still the intrinsic type real
   x = 4.0
   print *, x              ! 4.0
   print *, real           ! 1
end program test
```

and `integer :: trait = 1` followed by
`function f{Trait :: P}(...)` behaves the same way.

**Unconstrained parameters.** The main proposal's rule that an
unconstrained type parameter `{U}` stands for `{AnyType :: U}` is kept
for now. Whether it should be dropped, now that both types and traits
can be passed to generics, will be decided after more experience with
the prototype. A trait parameter therefore always needs its explicit
`Trait ::`.

### 3.3 E2: Conformance constraints between parameters

The constraint of a type parameter may be an *earlier trait parameter*
of the same list:

```fortran
subroutine register1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
```

`P :: U` requires the type bound to `U` to implement the trait bound to
`P`. Like every constraint, this is checked when the generic is
instantiated, i.e. at the call site. Registering a type under a trait it
does not implement is therefore a compile-time error:

```fortran
call cont%register{ILogger}(Printer)
! error: type 'Printer' does not implement trait 'ILogger',
!        as required for generic parameter 'U' of 'register0'
```

Swift accepts this registration and fails only at run time, in `as? P`.

### 3.4 E3: Initializers as procedure designators

A type name may appear as an actual argument associated with a dummy
procedure, or as the target of a procedure-pointer assignment. It then
designates the type's *initializer*:

```fortran
call cont%register{ILogger}(DoubleLogger)    ! DoubleLogger's initializer
p => DoubleLogger                            ! the same, as a pointer target
```

This is the counterpart of Swift's `DoubleLogger.init`. The initializer
designated is determined as follows:
1. If the type has initializer bindings (`initial :: ...` in the type or
   in an `implements` block, or a standard `interface DoubleLogger`),
   the designated procedure is chosen among them. If there is more than
   one, the choice is made by the interface of the dummy procedure or
   procedure pointer: exactly one must match, otherwise the reference
   is ambiguous. Where the initializer is accessible by its own name,
   the user can also name it instead.
2. Otherwise, the type's structure constructor is designated. Its
   interface has one `intent(in)` dummy argument per component, in
   component order, with the declared type, kind and rank of the
   component, and its result is a scalar of the type. This applies only
   where the structure constructor itself could be referenced: no
   inaccessible (`private`) components, no pointer components, and no
   components with default initialization. Otherwise, an initializer
   must be written. The compiler supplies a procedure with this
   interface, which exists for the whole execution of the program, so
   it may be stored in a procedure pointer.

The designation depends only on the accessibility of the type name, as
a reference to the type's constructor does. The specific initializer
procedures may be private, as `init` is in `DoubleLoggerMod`
(Sect. 4.6).

Rule 2 is the Fortran analogue of Swift's memberwise initializer. In
Swift the memberwise initializer is never public, so each type of the
Swift container, which lives in its own module, declares
`public init(...)`, even `Printer` and `Writer`. In Fortran a structure
constructor is usable outside its module unless the type has private
components. So `DoubleLogger`, whose components are private, declares
`initial :: init` (Sect. 4.6), while `Printer` and `Writer`, which have
no components at all, need nothing.

A generic derived type used as a procedure designator must be given its
type arguments explicitly, as in `Box{real}`. E8b does not apply here,
because there are no actual arguments to infer them from.

No standard program changes meaning. Standard Fortran allows neither a
type name nor a generic name, unless it is also the name of a specific
procedure, as an actual argument.

### 3.5 E4: Generic abstract interfaces and inference through dummy procedures

Swift writes the function type `(T1) -> U` inline. Fortran describes
procedure types by abstract interfaces, so we allow abstract interfaces
to have generic type parameters, exactly like generic procedures:

```fortran
abstract interface
   function ctor1{Trait :: T1, U}(a) result(res)
      class(T1), intent(in) :: a
      type(U)               :: res
   end function ctor1
end interface
```

An instance of it, `ctor1{T1,U}` or `ctor1{ILogger,Client}`, can be
used wherever an abstract interface name can be used:
`procedure(ctor1{T1,U}) :: ctor`, or a procedure-pointer component.

When a generic procedure has a dummy procedure whose interface mentions
its type parameters, those parameters are inferred from the actual
procedure. This extends the type inference the proposal already does
for data arguments, and works like Swift's inference through function
types:
- **Matching:** the actual procedure's characteristics are matched
  against the dummy's interface, argument by argument and for the
  result.
- **Binding parameters:**
  - `class(T)` with `T` a trait parameter binds `T` to the trait of the
    actual's dummy;
  - `type(U)` binds `U` to the type;
  - an intrinsic type binds the parameter to that type and kind.
- **No conversions:** after substitution the characteristics must agree
  as Fortran requires for any actual procedure (intent, rank,
  attributes; F2023 15.5.2.9). As for data arguments, no implicit
  conversions apply.

The actual procedure may itself be a dummy procedure, or a procedure
pointer, whose interface is an instance such as `ctor1{T1,U}` of an
enclosing generic. Its characteristics are then those of the instance,
so `register1`'s dummy `ctor` can be passed on to `Factory(ctor)`
(Sect. 4.5).

For example, `DoubleLogger`'s initializer:

```fortran
function init(printer, writer) result(self)
   class(IPrinter), intent(in) :: printer
   class(IWriter),  intent(in) :: writer
   type(DoubleLogger)          :: self
```

matched against `ctor2{T1,T2,U}` binds `T1 = IPrinter`, `T2 = IWriter`
and `U = DoubleLogger`. This is the "reflection on initializers" the
container needs: the compiler reads the initializer's signature, and
the generic code receives it as type arguments.

### 3.6 E5: Partially explicit type arguments

The proposal allows a generic's type arguments either to be inferred
completely or to be given completely, `sum{integer}(x)`. We also allow
the *leading* type arguments to be given and the rest to be inferred:

```fortran
call cont%register{ILogger}(DoubleLogger)
!                  ^ P given      ^ T1, T2, U inferred (E4)
```

This is how the meta-type argument of Swift, `ILogger.self`, is passed
in Fortran. A type argument cannot be inferred from a trait parameter
used only in the body (as `P` is in `register`), so such parameters are
placed first and given explicitly. If any parameter remains
undetermined, the call is an error that names it.

### 3.7 E6: Overloading of generic procedures

A generic interface, or a `generic ::` type-bound binding, may contain
*generic* specific procedures, alongside non-generic ones:

```fortran
type, sealed, implements(IResolver) :: Container
   ...
contains
   generic   :: register => register0, register1, register2
   procedure :: register0, register1, register2
   ...
end type
```

with:

```fortran
subroutine register0{Trait :: P, P :: U}(self, ctor)
   procedure(ctor0{U}) :: ctor
subroutine register1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
   procedure(ctor1{T1,U}) :: ctor
subroutine register2{Trait :: P, Trait :: T1, Trait :: T2, P :: U}(self, ctor)
   procedure(ctor2{T1,T2,U}) :: ctor
```

Fortran and Swift take opposite approaches to overloading. Fortran
requires the specifics of a generic interface to be *distinguishable*
at the point of declaration (F2023 15.4.3.4.5), so that a call can never
match two of them and no ranking is ever needed. Swift allows arbitrary
overlap and ranks the viable candidates at each call (Sect. 2.3). We
keep the Fortran approach, extended minimally, and adopt the one Swift
ranking rule that has a Fortran precedent.

**Declaration rule.** Any two specifics of a generic interface must be
distinguishable, with two extensions:

1. **Type parameters act as wildcards.** A dummy argument declared with
   a type parameter is treated as if it could have any type its
   constraint admits. Two specifics are distinguishable only if, for
   every possible instantiation, some argument position tells them
   apart by the usual type/kind/rank rules.
2. **Dummy procedures are distinguishable by their interfaces.** Two
   dummy procedures are distinguishable if:
   - one is a function and the other a subroutine; or
   - their interfaces have different numbers of non-optional dummy
     arguments; or
   - some pair of corresponding dummy arguments, or their function
     results, are distinguishable.

   Standard Fortran distinguishes two dummy procedures only if both
   are known to be functions whose results are not TKR compatible
   (F2023 15.4.3.4.5). The new rule adds the number of arguments and
   the arguments' characteristics. It only accepts generic interfaces
   that were previously rejected.

`register0`, `register1` and `register2` are distinguishable by rule 2:
their `ctor` interfaces have 0, 1 and 2 arguments. This is the Swift
container's disambiguation, by the arity of the function type.

**Exception: a non-generic specific may overlap a generic one.** This
is Swift's first ranking rule, "non-generic beats generic". It has a
direct Fortran precedent: a non-elemental specific is preferred over an
elemental one that also matches (F2023 15.5.5.2). It lets a library
provide a hand-written specialization next to a generic implementation:

```fortran
interface norm
   module procedure norm_generic        ! norm_generic{INumeric :: T}(x)
   module procedure norm_real64         ! hand-tuned for real(real64)
end interface
```

**Resolution rule.** A reference to a generic name is resolved as
follows:
1. The non-generic specifics are tried by the existing rules. If one
   matches, it is selected.
2. Otherwise each generic specific is tried. A specific is *viable* if:
   - the explicit type arguments, if any, are admitted by its leading
     parameters;
   - inference (E4) determines all remaining parameters;
   - all constraints (E2) are satisfied.

   By the declaration rule, at most one generic specific is viable, and
   it is selected and instantiated.
3. If no specific is viable, the error names each candidate and the
   reason it failed. For example: "register1: initializer of `Printer`
   has 0 arguments, the interface requires 1"; "register0: type
   `Printer` does not implement `ILogger`".

Swift's remaining ranking rules (more specialized, more constrained) are
*not* adopted. Overlapping generic specifics remain a declaration error,
in keeping with Fortran's design that resolution never has to rank
candidates. They could be added later without breaking any program
(Sect. 6).

### 3.8 E7: The `type_name` intrinsic

`type_name{P}()` is an intrinsic function that returns the name of the
type or trait `P`, as a `character` value. It is a constant expression
wherever `P` is known at compile time, which is everywhere except in the
erased code of E10. `P` is any type
argument: a derived type, a trait or an intrinsic type. Like other
intrinsic procedures, it is available in every scoping unit without a
`use` statement, and a user-declared entity of the same name hides it.
- **Unqualified form:** returns the name with the letter case of its
  declaration, e.g. `"ILogger"`. It is the analogue of Swift's
  `String(describing:)`.
- **Qualified form:** `type_name{P}(qualified=.true.)` prefixes the name
  of the defining module, as in `"ILoggerMod::ILogger"`. It is the
  analogue of Swift's `String(reflecting:)`, and is unique within a
  program.

The container uses the qualified form as its key, so two traits with the
same name in different modules never collide. It uses the unqualified
form in messages.

Inside an instantiated generic, `type_name{P}()` is a constant. Inside
the erased code of E10, both forms are read from the trait descriptor.
No other run-time type information is involved.

### 3.9 E8: Generic initializers

An initializer, i.e. a procedure bound to a type with `initial ::`, may
have type parameters of its own. They are independent of the type's
parameters: the type may itself be generic or not. This is the
counterpart of Swift's `init<T1,U>(...)`. The main proposal's rule that
an initializer does not declare the *type's* parameters, which it sees
through the type (Sect. "Constructors of generic types"), is
unchanged; E8 concerns additional parameters of the initializer
itself:

```fortran
type, sealed, implements(IFactory) :: Factory
   private
   class(IFactory), allocatable :: box
contains
   initial   :: init0, init1, init2
   procedure :: create
end type Factory

function init1{Trait :: T1, U}(ctor) result(self)
   procedure(ctor1{T1,U}) :: ctor
   type(Factory)          :: self
   self%box = Factory1(ctor)
end function init1
```

The rules are those of generic procedures:
- **Inference only.** In a reference such as `Factory(ctor)`, the
  initializer's type parameters are inferred from the actual arguments,
  including through dummy procedures (E4). They cannot be given
  explicitly, because braces after a type name, as in `Box{real}(...)`,
  give the *type's* arguments. Swift has the same restriction.
- **Result.** The result is the type being initialized. If the type is
  generic, its own parameters are visible in the initializer, as for any
  procedure bound to a generic type.
- **Constraints.** All constraints of the initializer's parameters
  (E2) are checked at the reference.

### 3.10 E8b: Inference of a generic type's parameters in constructor references

The main proposal already infers a generic type's parameters from the
actual arguments of a constructor reference, such as
`PairwiseSum(SimpleSum())`, and allows them to be given explicitly in
braces (Sect. "Constructors of generic types"). E8b extends this
inference to procedure arguments, through the rules of E4. This is the
counterpart of Swift's `Factory1(ctor: constructor)`, where
`Factory1<T1,U>`'s parameters are inferred from the function type of
`constructor`:

```fortran
type, sealed, implements(IFactory) :: Factory1{Trait :: T1, U}
   private
   procedure(ctor1{T1,U}), pointer, nopass :: ctor => null()
contains
   procedure :: create => create1
end type Factory1

self%box = Factory1(ctor)         ! Factory1{T1,U} with T1, U inferred
```

The rules:
- **What is matched.** The actual arguments are matched against the
  interface of what the reference designates:
  - the type's structure constructor, whose dummy arguments are the
    components, with their declared types, which may mention the type's
    parameters;
  - or the type's initializers, which are tried by the rules of E9.
- **How parameters are bound.** By the rules of E4, for data arguments
  and for procedures. In the example, the actual procedure `ctor` is
  matched against the interface `ctor1{T1,U}` of the procedure-pointer
  component `ctor`, which binds `T1` and `U`.
- **Errors.** If any parameter remains undetermined, the reference is an
  error that names it.
- **Only constructor references.** As in the main proposal, inference
  applies only where the type is referenced as a constructor with
  actual arguments. Type declarations such as `type(Factory1{T1,U})`
  and procedure designators (E3) need the type arguments explicitly.

The structure constructor itself is unchanged. It can be referenced only
where it could be referenced anyway, for example inside `FactoryMod`,
where `Factory1`'s private component `ctor` is accessible.

### 3.11 E9: Overloading of generic initializers

The main proposal already allows several initializers per type,
`initial :: init_by_int, init_by_real`, which overload the type's
structure constructor. E9 allows generic initializers among them, and
applies to them the declaration and resolution rules of E6:
- **Declaration.** The type's initializers must be pairwise
  distinguishable, with type parameters acting as wildcards and dummy
  procedures distinguishable by their interfaces. A non-generic
  initializer may overlap a generic one.
- **Resolution.** In a reference such as `Factory(ctor)`, the
  non-generic initializers are tried first, then the generic ones. At
  most one generic initializer is viable, and its parameters are
  inferred (E8).

`Factory`'s `init0`, `init1` and `init2` are distinguishable because
their `ctor` interfaces have 0, 1 and 2 arguments, as are `register0`,
`register1` and `register2`. A reference `Factory(ctor)` thus selects
the initializer by the arity of `ctor`, as Swift's `Factory.init`
overloads do.

It would be inconsistent to allow overloaded generic procedures (E6)
but not overloaded generic initializers, which are the procedures that
construct a type.

### 3.12 E10: Generic messages with trait parameters through trait objects

In Swift, `resolve<P>` is a requirement of the protocol `IResolver`, and
`Factory1.create` calls it on an existential `c`. E10 allows the same in
Fortran: a message of a trait may have trait parameters (E1), and may be
called through a trait object.

```fortran
abstract interface :: IResolver
   function resolve{Trait :: P}(self) result(res)
      type(itself), pass, intent(in) :: self
      class(P),           allocatable :: res
   end function resolve
end interface

function create1(self, c) result(res)
   type(Factory1{T1,U}), intent(in)  :: self
   class(IResolver),     intent(in)  :: c
   class(*),             allocatable :: res
   res = self%ctor(c%resolve{T1}())        ! Swift: ctor(c.resolve(T1.self))
end function create1
```

A type implements such a message by a generic procedure with the same
type-parameter list, as for any generic message. `Container`'s
`resolve{Trait :: P}` is an example (Sect. 4.5).

**The problem it solves.** A trait object is a pair of a data pointer
and a pointer to a table that the dynamic type provides for the trait.
The table has one entry, or *slot*, per message. It is filled where a
value of a concrete type becomes a trait object, and each slot must
then hold one procedure. A statically instantiated generic message is a
family of procedures, one per type argument, and the set of type
arguments that later callers will use is open. So there is no single
procedure to place in the slot.

**The solution.** The slot holds a single *erased* copy of the
implementing procedure. It is compiled once, in the module that
implements the message, and receives each trait argument as a hidden
run-time argument: a *trait descriptor*. A trait descriptor is a
constant record, one per trait, that holds the trait's unqualified and
qualified names (E7) and its identity for run-time conformance
queries.

Every use of a trait parameter `P` that E1 allows can be carried out
with the descriptor alone:
- **`class(P)` declarations:** a trait object has the same
  representation for every trait, a data pointer and a table pointer, so
  its size and layout do not depend on `P`.
- **`select type ... class is (P)`:** the run-time conformance query
  that `class is (ILogger)` performs, with the trait taken from the
  descriptor. The query yields the dynamic type's table for `P`.
- **Assigning to a `class(P)` result:** the data pointer is paired with
  the table found by the query.
- **`type_name{P}()`:** the names are read from the descriptor.
- **Passing `P` on** to another generic: the descriptor is passed on.

`type(P)` is not allowed by E1, so the layout of `P` is never needed.
Trait parameters are therefore the easiest kind of type parameter to
erase, and the erased body needs no restrictions beyond those of E1.

**Compilation model.** Fortran's static instantiation is kept. A
generic message is compiled in two forms:
- **Static instances,** wherever the type arguments are known at
  compile time. This includes every call on a non-polymorphic object,
  such as `cont%resolve{IClient}()` on a `type(Container)`, and every
  call that the compiler can devirtualize, for example because the
  dynamic type is a known `sealed` type.
- **One erased copy,** placed in the slot of the implementing type's
  table for the trait.

At a call through a trait object, such as `c%resolve{T1}()` in the
instance `Factory1{ILogger,Client}`, the compiler loads the slot and
passes the descriptor of `ILogger`, which is a compile-time constant
there. No code is generated at run time, and no meta-type values are
visible to the user.

**Scope.** E10 covers trait parameters. Generic messages whose type
parameters range over types are dispatched through trait objects by
the means the LFortran prototype already implements: one slot per
member for closed type sets, and dictionary passing of the type's
witness table for open traits
([answers](traits-di-review-answers.md), Sect. 2 and Appendix A).

**Run-time cost.** The conformance query and the call through the table
are the same work that Swift's `as? P` and its witness-table call do.

### 3.13 Type erasure through generic factory types

Swift's `Factory0`, `Factory1` and `Factory2` become generic derived
types that store the initializer in a procedure-pointer component and
implement a one-message trait `IFactory`:

```fortran
abstract interface :: IFactory
   function create(self, c) result(res)
      type(itself), pass, intent(in)  :: self
      class(IResolver),   intent(in)  :: c
      class(*),           allocatable :: res
   end function create
end interface
```

`Factory1{T1,U}` and `create1` are shown in Sects. 3.10 and 3.12.
Compare them with Swift's `Factory1<T1,U>` (Sect. 2.2):
- the stored `ctor` is the procedure-pointer component `ctor`;
- `T1` is the instance's type parameter, passed on to `resolve` as a
  trait argument;
- `any IFactory` is a `class(IFactory)` trait object.

The decorator `Factory` holds one of them in its `box` component, and
its generic, overloaded initializers (E8, E9) construct the right one
with inferred type arguments (E8b). The container stores the factories
as `class(IFactory)` trait objects in its map. This type-erases them,
just as Swift's dictionary of `any IFactory` does.

Everything else used here is already in the proposal:
- generic derived types;
- type-bound procedures that see the type's parameters;
- trait objects;
- `class(*)` results.

## 4. The complete Fortran container

The code below is that of the
[`projected`](https://github.com/difference-scheme/FortranDIContainer/tree/projected)
branch of FortranDIContainer, which uses all of E1–E10, with shortened
comments and one correction in `resolve` (Sect. 4.5). The file layout
mirrors the Swift repository. `FactoryMapMod`, the hash map, and the
modules of the traits `IClient`, `IPrinter` and `IWriter` and of the
types `Client`, `SingleLogger`, `Printer` and `Writer` are not repeated
in full.

### 4.1 Traits of the application (unchanged)

`ILoggerMod`, `IClientMod`, `IPrinterMod` and `IWriterMod` stay as
they are. For example:

```fortran
abstract interface :: ILogger
   subroutine log(self)
      type(itself), pass, intent(in) :: self
   end subroutine log
end interface

abstract interface, extends(ILogger) :: IClient
end interface
```

### 4.2 `IResolverMod.f90` and `IFactoryMod.f90`

```fortran
module IResolverMod
   implicit none

   abstract interface :: IResolver
      function resolve{Trait :: P}(self) result(res)
         type(itself), pass, intent(in)  :: self
         class(P),           allocatable :: res
      end function resolve
   end interface

end module IResolverMod
```

```fortran
module IFactoryMod
   use IResolverMod, only: IResolver
   implicit none

   !.. Swift: protocol IFactory { func create(_ c: any IResolver) -> Any }
   abstract interface :: IFactory
      function create(self, c) result(res)
         type(itself), pass, intent(in)  :: self
         class(IResolver),   intent(in)  :: c
         class(*),           allocatable :: res
      end function create
   end interface

end module IFactoryMod
```

### 4.3 `InterfacesMod.f90`

```fortran
module InterfacesMod
   implicit none

   !.. Swift: () -> U,  (T1) -> U,  (T1, T2) -> U
   abstract interface
      function ctor0{U}() result(res)
         type(U) :: res
      end function ctor0

      function ctor1{Trait :: T1, U}(a) result(res)
         class(T1), intent(in) :: a
         type(U)               :: res
      end function ctor1

      function ctor2{Trait :: T1, Trait :: T2, U}(a, b) result(res)
         class(T1), intent(in) :: a
         class(T2), intent(in) :: b
         type(U)               :: res
      end function ctor2
   end interface

end module InterfacesMod
```

`U` is unconstrained, i.e. constrained by `AnyType`.

### 4.4 `FactoryMod.f90`

```fortran
module FactoryMod
   use IFactoryMod,   only: IFactory
   use IResolverMod,  only: IResolver
   use InterfacesMod, only: ctor0, ctor1, ctor2
   implicit none
   private
   public :: Factory

   !.. the type-erasing decorator (Swift: struct Factory)
   type, sealed, implements(IFactory) :: Factory
      private
      class(IFactory), allocatable :: box
   contains
      initial   :: init0, init1, init2                   ! E8, E9
      procedure :: create
   end type Factory

   !.. helper types for type erasure, one per initializer arity
   type, sealed, implements(IFactory) :: Factory0{U}
      private
      procedure(ctor0{U}), pointer, nopass :: ctor => null()
   contains
      procedure :: create => create0
   end type Factory0

   type, sealed, implements(IFactory) :: Factory1{Trait :: T1, U}
      private
      procedure(ctor1{T1,U}), pointer, nopass :: ctor => null()
   contains
      procedure :: create => create1
   end type Factory1

   type, sealed, implements(IFactory) :: Factory2{Trait :: T1, Trait :: T2, U}
      private
      procedure(ctor2{T1,T2,U}), pointer, nopass :: ctor => null()
   contains
      procedure :: create => create2
   end type Factory2

contains

   function init0{U}(ctor) result(self)
      procedure(ctor0{U}) :: ctor
      type(Factory)       :: self
      self%box = Factory0(ctor)                          ! E8b
   end function init0

   function init1{Trait :: T1, U}(ctor) result(self)
      procedure(ctor1{T1,U}) :: ctor
      type(Factory)          :: self
      self%box = Factory1(ctor)
   end function init1

   function init2{Trait :: T1, Trait :: T2, U}(ctor) result(self)
      procedure(ctor2{T1,T2,U}) :: ctor
      type(Factory)             :: self
      self%box = Factory2(ctor)
   end function init2

   function create(self, c) result(res)
      type(Factory),    intent(in)  :: self
      class(IResolver), intent(in)  :: c
      class(*),         allocatable :: res
      res = self%box%create(c)
   end function create

   function create0(self, c) result(res)
      type(Factory0{U}), intent(in)  :: self
      class(IResolver),  intent(in)  :: c
      class(*),          allocatable :: res
      res = self%ctor()
   end function create0

   function create1(self, c) result(res)
      type(Factory1{T1,U}), intent(in)  :: self
      class(IResolver),     intent(in)  :: c
      class(*),             allocatable :: res
      res = self%ctor(c%resolve{T1}())                   ! E10
   end function create1

   function create2(self, c) result(res)
      type(Factory2{T1,T2,U}), intent(in)  :: self
      class(IResolver),        intent(in)  :: c
      class(*),                allocatable :: res
      res = self%ctor(c%resolve{T1}(), c%resolve{T2}())
   end function create2

end module FactoryMod
```

### 4.5 `ContainerMod.f90`

```fortran
module ContainerMod
   use IResolverMod,  only: IResolver
   use IFactoryMod,   only: IFactory
   use InterfacesMod, only: ctor0, ctor1, ctor2
   use FactoryMapMod, only: FactoryMap
   use FactoryMod,    only: Factory
   implicit none
   private
   public :: Container

   !...........................................................
   ! Dependency injection container for traits.
   ! Employs trait parameters and overloading of generic methods.
   !...........................................................
   type, sealed, implements(IResolver) :: Container
      private
      type(FactoryMap) :: factories
   contains
      initial   :: init
      generic   :: register => register0, register1, register2
      procedure :: register0, register1, register2
      procedure :: resolve
   end type Container

contains

   function init() result(self)
      type(Container) :: self
   end function init

   !.. registration for initializers taking no arguments
   subroutine register0{Trait :: P, P :: U}(self, ctor)
      type(Container), intent(inout) :: self
      procedure(ctor0{U})            :: ctor
      key := type_name{P}(qualified=.true.)
      call self%factories%store(key, Factory(ctor))
   end subroutine register0

   !.. registration for initializers taking one argument, of trait T1
   subroutine register1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
      type(Container), intent(inout) :: self
      procedure(ctor1{T1,U})         :: ctor
      key := type_name{P}(qualified=.true.)
      call self%factories%store(key, Factory(ctor))
   end subroutine register1

   !.. registration for initializers taking two arguments, of traits T1 and T2
   subroutine register2{Trait :: P, Trait :: T1, Trait :: T2, P :: U}(self, ctor)
      type(Container), intent(inout) :: self
      procedure(ctor2{T1,T2,U})      :: ctor
      key := type_name{P}(qualified=.true.)
      call self%factories%store(key, Factory(ctor))
   end subroutine register2

   !.. call the factory registered for trait P, passing it this
   !.. container, to resolve dependencies recursively
   function resolve{Trait :: P}(self) result(res)
      type(Container), intent(in)  :: self
      class(P),        allocatable :: res
      class(IFactory), allocatable :: fact
      key := type_name{P}(qualified=.true.)
      call self%factories%retrieve(key, fact)
      if (.not. allocated(fact)) &
         error stop "No registration available for " // type_name{P}() // "!"
      select type (obj => fact%create(self))
      class is (P)
         res = obj
      class default
         error stop "No registration available for " // type_name{P}() // "!"
      end select
   end function resolve

end module ContainerMod
```

`FactoryMapMod` is the present hash map, with its value changed from a
procedure pointer to a `class(IFactory), allocatable` component. Its
`store(key, factory)` copies the factory object, and its
`retrieve(key, factory)` returns a copy of the stored one, or leaves
`factory` unallocated if there is none. The check of `fact` in
`resolve` covers that case; without it, `fact%create(self)` would
reference an unallocated object. Swift covers it with the optional
chaining in `factories[key]?.create(self)`.

Compared with Swift's `Container.swift`, which imports `IResolver`,
`IFactory` and `Factory`, the only additional dependencies are
`InterfacesMod`, which holds what Swift writes inline as function types,
and `FactoryMapMod`, which stands in for Swift's built-in dictionary.

### 4.6 Implementing types

The `create_X` functions disappear. Each type declares the initializer
it needs, the Fortran counterpart of Swift's `public init`, and exports
the type.

```fortran
module DoubleLoggerMod
   use ILoggerMod,  only: ILogger
   use IPrinterMod, only: IPrinter
   use IWriterMod,  only: IWriter
   implicit none
   private
   public :: DoubleLogger

   type, implements(ILogger) :: DoubleLogger
      private
      class(IPrinter), allocatable :: printer
      class(IWriter),  allocatable :: writer
   contains
      initial   :: init
      procedure :: log
   end type DoubleLogger

contains

   function init(printer, writer) result(self)
      class(IPrinter), intent(in) :: printer
      class(IWriter),  intent(in) :: writer
      type(DoubleLogger)          :: self
      self%printer = printer
      self%writer  = writer
   end function init

   subroutine log(self)
      class(DoubleLogger), intent(in) :: self
      write(*,*) "logging by "
      call self%printer%printout()
      call self%writer%writeout()
   end subroutine log

end module DoubleLoggerMod
```

`Client` and `SingleLogger` follow the same pattern, with an
initializer of one argument. Their components are private, so they
need an explicit initializer (E3, rule 2). `Printer` and `Writer` have
no components, so their structure constructors `Printer()` and
`Writer()` serve as initializers, and they need nothing at all:

```fortran
type, implements(IPrinter) :: Printer
contains
   procedure, nopass :: printout
end type Printer
```

### 4.7 `Main.f90`

```fortran
program main
   use IClientMod,      only: IClient
   use ILoggerMod,      only: ILogger
   use IPrinterMod,     only: IPrinter
   use IWriterMod,      only: IWriter
   use ContainerMod,    only: Container
   use ClientMod,       only: Client
   use SingleLoggerMod, only: SingleLogger
   use DoubleLoggerMod, only: DoubleLogger
   use PrinterMod,      only: Printer
   use WriterMod,       only: Writer
   implicit none

   type(Container), allocatable :: cont
   class(IClient),  allocatable :: cobj

   !.. get a dependency injection container
   cont = Container()

   !.. register a concrete type (initializer) with each trait
   call cont%register{IClient}(Client)
   call cont%register{ILogger}(DoubleLogger)
   call cont%register{IPrinter}(Printer)
   call cont%register{IWriter}(Writer)

   !.. recursively resolve the object graph, starting at the top trait
   cobj = cont%resolve{IClient}()

   !.. use the constructed object
   call cobj%log()

end program main
```

The output is the same as Swift's:

```
 Calling logger from client:
 logging by
 printing  ...
 writing  ...
```

Switching to single logging means changing one line, to
`call cont%register{ILogger}(SingleLogger)`. The `IWriter` registration
is then simply unused.

### 4.8 What the compiler does

For `call cont%register{ILogger}(DoubleLogger)`:
1. **Resolve `register` (E6).** There are no non-generic specifics.
   Each generic specific is tried:
   - `register0` and `register1` are not viable, because
     `DoubleLogger`'s initializer has 2 arguments.
   - `register2` is viable.
2. **Bind the explicit argument (E1, E5).** `P = ILogger` is given
   explicitly.
3. **Infer the rest (E3, E4).** `DoubleLogger` designates `init`.
   Matching `init` against `ctor2{T1,T2,U}` infers `T1 = IPrinter`,
   `T2 = IWriter` and `U = DoubleLogger`.
4. **Check the constraint (E2).** `ILogger :: DoubleLogger` holds, since
   `DoubleLogger` implements `ILogger`.
5. **Instantiate** `register2{ILogger, IPrinter, IWriter, DoubleLogger}`.
   In its body:
   - `type_name{ILogger}(qualified=.true.)` is the constant
     `"ILoggerMod::ILogger"` (E7).
   - `Factory(ctor)` selects `init2` among `Factory`'s initializers by
     the arity of `ctor` (E9), and infers its parameters from `ctor`'s
     interface `ctor2{IPrinter,IWriter,DoubleLogger}` (E8, E4).
   - In `init2`'s instance, `Factory2(ctor)` infers
     `Factory2{IPrinter, IWriter, DoubleLogger}` from `ctor` (E8b).
6. **Instantiate `create2`** for that instance of `Factory2`. Its two
   calls `c%resolve{IPrinter}()` and `c%resolve{IWriter}()` go through
   the `resolve` slot of `c`'s table, passing the descriptors of
   `IPrinter` and `IWriter` (E10). `create2` is precisely the former
   hand-written `create_DoubleLogger`.

For `cobj = cont%resolve{IClient}()`, `cont` is a `type(Container)`, so
`resolve{IClient}` is a static instance (E10's compilation model). In
addition, `ContainerMod` contains one erased copy of `resolve`, which
is placed in the `resolve` slot of `Container`'s table for `IResolver`.
It is the procedure that the factories' `c%resolve{...}()` calls reach
when `fact%create(self)` passes the container to them as a
`class(IResolver)`.

## 5. Present restrictions

- **Maximum arity.** As in the Swift original, the container supports
  initializers up to a fixed number of arguments, one overload per
  arity. A production container would provide, say, six. Variadic
  generics would remove this (Sect. 6).
- **Dependencies must be traits.** Initializer arguments are resolved
  by trait. An argument of a concrete type, or a configuration value
  such as an integer or a file name, cannot be resolved this way. The
  same holds in Swift, unless such values are registered too. Such
  types keep a hand-written factory, which can be registered alongside
  (the container can offer a `register{P}(factory)` overload taking an
  `IFactory` object).
- **Exact interface match.** The initializer's dummy arguments must be
  declared exactly as the container's interfaces expect:
  `class(T), intent(in)`, no `optional`, no keyword reordering.
- **Explicit initializers for private components.** A type with private
  components needs an explicit initializer to be registered from
  outside its module (E3, rule 2), as `Client`, `SingleLogger` and
  `DoubleLogger` have.
- **Lifetimes.** As for any procedure pointer, a factory must not
  capture an internal procedure whose host has returned. This does not
  arise for E3: initializers are module procedures, and the procedure
  supplied for a structure constructor exists for the whole execution
  of the program.
- **Instance lifetime.** Each `resolve` creates new objects. Singletons
  and scoped lifetimes are a container design question, not a language
  one.

## 6. Decisions taken in review, and outlook

**Decisions** (see [traits-di-review.md](traits-di-review.md), Sect. 5):
1. **Spelling of trait parameters.** `{Trait :: P}`, with the predefined
   meta-trait `Trait`. The empty trait `IAnyType` is renamed to
   `AnyType`. Both follow the rules of intrinsic type names and are not
   reserved words (Sect. 3.2). The main proposal will be updated
   accordingly.
2. **Unconstrained type parameters.** They keep meaning `AnyType` for
   now. Whether to require explicit constraints will be decided after
   more experience with the prototype.
3. **Overlap of generic specifics.** Fortran's rule is kept: overlapping
   specifics are a declaration error, except non-generic over generic.
   Swift's "more specialized" and "more constrained" ranking rules are
   not adopted.
4. **Implicit structure constructors as initializers (E3, rule 2).**
   They count, where they are accessible.
5. **`type_name` result form.** To be decided after more experience
   with the prototype. The qualified form `Module::Name`, with the
   letter case of the declarations, is provisional.

**Outlook:**
- **Variadic generics.** Swift 5.9 added parameter packs
  (`register<P, each T, U>(_: P.Type, _: (repeat each T) -> U)`), which
  reduce the three overloads to one. A Fortran analogue,
  `{Trait, dimension(*) :: T}`, would do the same here.
- **Default methods in traits.** Swift's protocol extensions add methods
  with bodies to a protocol. A Fortran analogue would give method syntax
  to helper procedures that use only a trait's messages.
- **Parameterized traits.** Traits with their own type parameters, as in
  Rust and Go, would let the factory map hold
  `class(IFactory{Container})`. All calls of `resolve` would then be
  static, and only the map lookup would remain dynamic
  ([answers](traits-di-review-answers.md), Sect. 8).
- **Meta-type values.** Storing types in variables, as Swift's `P.Type`
  allows, is not needed for DI. It would be a far larger extension.
