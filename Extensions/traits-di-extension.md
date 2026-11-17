# Traits extension: overloaded generic procedures and initializer reflection

*A proposed extension to the Fortran traits proposal, motivated by
dependency injection. Draft for review; nothing described here is
implemented yet.*

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
- **Overloading of generic functions;**
- **A small amount of reflection:**
  - meta-types;
  - initializers usable as function values;
  - type inference through function-typed arguments.

This document:
- analyzes how the Swift container works (Sect. 2);
- proposes the minimal set of Fortran extensions that achieves the same
  (Sect. 3);
- shows the complete ported container (Sect. 4);
- closes with restrictions, open questions and an outlook (Sects. 5–6).

The end result for the user is:

```fortran
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

## 2. How it works in Swift

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
public mutating func register<P,T,U>(_ protocolType: P.Type,
                                     _ constructor: @escaping (T) -> U)
```

Passing `Client.init`, of type `(ILogger) -> Client`, binds `T` to
`ILogger` and `U` to `Client`. The compiler does so by unifying the
function type of the actual argument with the function type of the
parameter.

**Overloading of generic functions.** Swift has no variadic generics in
the version used here, so there are three overloads of `register` and
of `Factory.init`, for initializers of zero, one and two arguments:

```swift
func register<P,T>    (_: P.Type, _ constructor: @escaping ()     -> T)
func register<P,T,U>  (_: P.Type, _ constructor: @escaping (T)    -> U)
func register<P,T,U,V>(_: P.Type, _ constructor: @escaping (T, U) -> V)
```

Only the overload whose function type has the right number of
parameters can accept a given initializer, so the call resolves
uniquely.

**Closures and type erasure.** Each overload of `Factory.init` wraps the
initializer in a closure. The closure captures the initializer and
resolves its arguments recursively through the container:

```swift
public init<T,U>(_ constructor: @escaping (T) -> U) {
    create = { c in
        return constructor(c.resolve(T.self))
    }
}
```

All closures have the same type, `IFactory = (IResolver) -> Any`, so
they can be stored in one dictionary keyed by the protocol name. This
*type-erases* the different initializers.

**Dynamic casts.** `resolve` looks up the closure, calls it, and casts
the `Any` result back with `as? P`. The cast is checked at run time
against the protocol conformance records of the dynamic type:

```swift
public func resolve<P>(_ protocolType: P.Type) -> P {
    let key = String(describing: protocolType)
    guard let create = factories[key],
          let instance = create(self) as? P else {
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

Swift never rejects overlapping overloads at the point of declaration;
ambiguity is diagnosed only at a call. Its rules are not given in a
formal specification. They live in the type checker's ranking code
(`CSRanking.cpp`) and are described informally in the compiler's
`docs/TypeChecker.md`.

The DI container only needs the simplest case: overloads that differ in
the *arity of a function-typed parameter*. For a given initializer only
one overload is viable, and no ranking is needed at all.

### 2.4 What Swift does at run time

Swift generics need not be specialized at compile time. A call
`c.resolve(T.self)` inside a closure works even though `c` is an
existential (`IResolver`, a protocol-typed value). The type metadata of
`T` is captured by the closure and passed to `resolve` at run time. Two
other things also happen at run time:
- the `as? P` cast;
- a failed lookup, which is a run-time `fatalError`.

In particular, nothing checks at compile time that
`register(ILogger.self, Printer.init)` registers a type that conforms to
`ILogger`.

## 3. The Fortran design

### 3.1 Overview

The design maps each Swift ingredient to a Fortran counterpart. Most of
the needed machinery already exists in the proposal:
- generic procedures and generic derived types;
- type inference;
- initializers;
- trait objects;
- `select type` with `class is (ITrait)`.

What is missing are seven small extensions, E1–E7:

| Swift | Fortran (this proposal) | |
|---|---|---|
| `P.Type`, `IClient.self` | trait parameters `{abstract interface :: P}`; explicit type argument `register{IClient}(...)` | E1, E5 |
| (runtime check `as? P` only) | conformance constraints between parameters, `{P :: U}` | E2 |
| `DoubleLogger.init` as a value | the type name designates its initializer: `register{ILogger}(DoubleLogger)` | E3 |
| inference from `(T) -> U` | generic abstract interfaces, and inference through dummy procedures | E4 |
| `register<P,T>`, `register<P,T,U>`, ... overloads | overloading of generic procedures | E6 |
| `String(describing: P.self)` | intrinsic `type_name{P}()` | E7 |
| escaping closure `{ c in ... }` | a generic derived type implementing an `IFactory` trait | (existing) |
| `as? P` | `select type ... class is (P)` | (existing) |

(E5, partially explicit type arguments, is listed separately because it
is useful on its own.)

Two Swift features are deliberately *not* adopted:
- **Escaping closures.** Fortran has no closures that outlive their
  host. A closure is an object with one method, and the proposal
  already has objects with methods. A generic derived type that
  implements a one-message trait does exactly what the Swift closure
  does, with no new language feature (Sect. 3.9).
- **Meta-type values.** Fortran's generics are instantiated statically,
  and the proposal already has a syntax for passing types to generic
  procedures: explicit type arguments in curly braces. A type or trait
  passed in braces plays the role of Swift's `IClient.self`. A
  first-class meta-type *value*, storable in variables, would be a much
  larger addition, and is not needed here.

### 3.2 E1: Trait parameters

A generic type parameter may range over *traits*, not only over types.
It is declared with the meta-constraint `abstract interface`, mirroring
how a trait itself is declared:

```fortran
function resolve{abstract interface :: P}(c) result(res)
   class(IResolver), intent(in)  :: c
   class(P),         allocatable :: res
   ...
end function resolve
```

The corresponding type argument must be a trait:
`resolve{IClient}(cont)`. A trait combination such as `IA + IB` is also
allowed. Inside the generic, a trait parameter `P` may be used wherever
a trait name may be used:
- in `class(P)` declarations of trait objects (owners, views and
  pointers);
- in `select type` guards `class is (P)`;
- as the constraint of another type parameter (E2);
- as a type argument of other generics;
- in `type_name{P}()` (E7).

It may not be used in `type(P)`: a trait is not a type.

Since instantiation is static, an instance such as `resolve{IClient}`
is ordinary code in which `P` has been replaced by `IClient`. Its
`class is (IClient)` guard is the existing run-time conformance query,
so the run-time machinery is the existing one.

### 3.3 E2: Conformance constraints between parameters

The constraint of a type parameter may be an *earlier trait parameter*
of the same list:

```fortran
subroutine register1{abstract interface :: P, abstract interface :: T, P :: U}(self, ctor)
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
   is ambiguous. The user can always name the specific initializer
   function instead.
2. Otherwise, the type's structure constructor is designated. Its
   interface has one `intent(in)` dummy argument per component, in
   component order, with the declared type, kind and rank of the
   component, and its result is a scalar of the type. This applies only
   where the structure constructor itself could be referenced: no
   inaccessible (`private`) components, no pointer components, and no
   components with default initialization. Otherwise, an initializer
   must be written.

Rule 2 is the Fortran analogue of Swift's memberwise initializer. Both
need to be written out explicitly once the stored properties are
private. This is why the Swift `DoubleLogger` declares
`public init(...)` and the Fortran one declares `initial :: init`
(Sect. 4).

No standard program changes meaning. Standard Fortran allows neither a
type name nor a generic name as an actual argument.

### 3.5 E4: Generic abstract interfaces and inference through dummy procedures

Swift writes the function type `(T) -> U` inline. Fortran describes
procedure types by abstract interfaces, so we allow abstract interfaces
to have generic type parameters, exactly like generic procedures:

```fortran
abstract interface
   function initializer1{abstract interface :: T, IAnyType :: U}(a) result(res)
      class(T), intent(in) :: a
      type(U)              :: res
   end function initializer1
end interface
```

An instance of it, `initializer1{T,U}` or `initializer1{IPrinter,Printer}`,
can be used wherever an abstract interface name can be used:
`procedure(initializer1{T,U}) :: ctor`, or a procedure-pointer
component.

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

For example, `DoubleLogger`'s initializer:

```fortran
function init(printer, writer) result(self)
   class(IPrinter), intent(in) :: printer
   class(IWriter),  intent(in) :: writer
   type(DoubleLogger)          :: self
```

matched against `initializer2{T1,T2,U}` binds `T1 = IPrinter`,
`T2 = IWriter` and `U = DoubleLogger`. This is the "reflection on
initializers" the container needs: the compiler reads the
initializer's signature, and the generic code receives it as type
arguments.

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
type, implements(IResolver) :: Container
   ...
contains
   generic :: register => register0, register1, register2
   ...
end type
```

with:

```fortran
subroutine register0{abstract interface :: P, P :: U}(self, ctor)
   procedure(initializer0{U}) :: ctor
subroutine register1{abstract interface :: P, abstract interface :: T, P :: U}(self, ctor)
   procedure(initializer1{T,U}) :: ctor
subroutine register2{abstract interface :: P, abstract interface :: T1, &
                     abstract interface :: T2, P :: U}(self, ctor)
   procedure(initializer2{T1,T2,U}) :: ctor
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

   Standard Fortran has no such rule. Two dummy procedures are
   indistinguishable in standard Fortran, so this only accepts generic
   interfaces that were previously rejected.

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
1. The non-generic specifics are tried by the existing rules, including
   the proposal's conformance tier for trait-view dummies. If one
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

`type_name{P}()` is an intrinsic function of the `generics` intrinsic
module that returns the name of the type or trait `P`, as a `character`
constant expression. `P` is any type argument: a derived type, a trait
or an intrinsic type.
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

Inside an instantiated generic, `type_name{P}()` is a constant. No
run-time type information is involved.

### 3.9 Closures: generic factory types

Swift's `Factory` stores a closure that captures the initializer. In
Fortran, the closure becomes an *object*. It is an instance of a generic
derived type that holds the initializer in a procedure-pointer
component, and implements a one-message trait `IFactory`:

```fortran
abstract interface :: IFactory
   function create(self, c) result(res)
      type(itself), pass, intent(in)  :: self
      class(IResolver),   intent(in)  :: c
      class(*),           allocatable :: res
   end function create
end interface

type, implements(IFactory) :: Factory1{abstract interface :: T, IAnyType :: U}
   procedure(initializer1{T,U}), pointer, nopass :: ctor => null()
contains
   procedure :: create => create1
end type

function create1(self, c) result(res)
   class(Factory1{T,U}), intent(in)  :: self
   class(IResolver),     intent(in)  :: c
   class(*),             allocatable :: res
   res = self%ctor(resolve{T}(c))          ! the Swift closure body
end function create1
```

Compare `create = { c in return constructor(c.resolve(T.self)) }`:
- the captured `constructor` is the component `ctor`;
- the captured type `T` is the instance's type parameter;
- the closure type `IFactory = (IResolver) -> Any` is the trait
  `IFactory`.

The container stores the factories as `class(IFactory), allocatable`
trait objects. This type-erases them, just as Swift's dictionary of
closures does. Everything used here is already in the proposal:
- generic derived types;
- type-bound procedures that see the type's parameters;
- trait objects;
- `class(*)` results.

Only the component's interface, `initializer1{T,U}`, needs E4.

### 3.10 Why `resolve` is not a generic message of `IResolver`

In Swift, `resolve<P>` is a requirement of the protocol `IResolver`, and
the closure calls it on an existential. This works because Swift passes
`P`'s metadata at run time. With static instantiation this is not
possible:
- a trait object's runtime contract has one slot per message;
- a generic message would need one slot per instantiation;
- the set of instantiations is open, i.e. unknown when the trait object
  is formed.

The proposal restricts runtime generic messages to closed type sets for
this reason.

The Fortran design therefore splits `resolve` in two:
- **A non-generic message:** `resolve_key(key) result(class(*))` is a
  message of `IResolver`, dispatched at run time.
- **A generic procedure:** `resolve{P}(c)` is an ordinary generic
  procedure over `class(IResolver)`. It is statically instantiated once
  per trait, and it computes the key with `type_name`, calls the
  message, and downcasts with `class is (P)`.

This is the same split as a Swift protocol *extension* method. The
container type additionally offers `resolve{P}` as a generic method, so
that the user writes `cont%resolve{IClient}()`.

## 4. The complete Fortran container

The file layout mirrors the Swift repository. Unchanged files of the
present Fortran version are not repeated.

### 4.1 Traits (unchanged)

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

### 4.2 `IResolverMod.f90`

```fortran
module IResolverMod
   use, intrinsic :: generics, only: type_name
   implicit none
   private
   public :: IResolver, resolve

   abstract interface :: IResolver
      function resolve_key(self, key) result(res)
         type(itself), pass, intent(in)  :: self
         character(*),       intent(in)  :: key
         class(*),           allocatable :: res
      end function resolve_key
   end interface

contains

   function resolve{abstract interface :: P}(c) result(res)
      !.............................................................
      ! Resolve the registration of trait P and return it as a
      ! trait object of P (Swift: c.resolve(P.self)).
      !.............................................................
      class(IResolver), intent(in)  :: c
      class(P),         allocatable :: res

      select type( obj => c%resolve_key(type_name{P}(qualified=.true.)) )
      class is (P)
         res = obj
      class default
         error stop "No registration available for " // type_name{P}()
      end select
   end function resolve

end module IResolverMod
```

### 4.3 `IFactoryMod.f90`

```fortran
module IFactoryMod
   use IResolverMod, only: IResolver
   implicit none
   private
   public :: IFactory, initializer0, initializer1, initializer2

   !.. Swift: typealias IFactory = (IResolver) -> Any
   abstract interface :: IFactory
      function create(self, c) result(res)
         type(itself), pass, intent(in)  :: self
         class(IResolver),   intent(in)  :: c
         class(*),           allocatable :: res
      end function create
   end interface

   !.. Swift: () -> U,  (T) -> U,  (T1, T2) -> U
   abstract interface
      function initializer0{IAnyType :: U}() result(res)
         type(U) :: res
      end function initializer0

      function initializer1{abstract interface :: T, IAnyType :: U}(a) result(res)
         class(T), intent(in) :: a
         type(U)              :: res
      end function initializer1

      function initializer2{abstract interface :: T1, abstract interface :: T2, &
                            IAnyType :: U}(a, b) result(res)
         class(T1), intent(in) :: a
         class(T2), intent(in) :: b
         type(U)               :: res
      end function initializer2
   end interface

end module IFactoryMod
```

### 4.4 `FactoryMod.f90`

```fortran
module FactoryMod
   use IResolverMod, only: IResolver, resolve
   use IFactoryMod,  only: IFactory, initializer0, initializer1, initializer2
   implicit none
   private
   public :: Factory0, Factory1, Factory2

   !.. one generic "closure" type per initializer arity

   type, implements(IFactory) :: Factory0{IAnyType :: U}
      procedure(initializer0{U}), pointer, nopass :: ctor => null()
   contains
      procedure :: create => create0
   end type Factory0

   type, implements(IFactory) :: Factory1{abstract interface :: T, IAnyType :: U}
      procedure(initializer1{T,U}), pointer, nopass :: ctor => null()
   contains
      procedure :: create => create1
   end type Factory1

   type, implements(IFactory) :: Factory2{abstract interface :: T1, &
                                          abstract interface :: T2, IAnyType :: U}
      procedure(initializer2{T1,T2,U}), pointer, nopass :: ctor => null()
   contains
      procedure :: create => create2
   end type Factory2

contains

   function create0(self, c) result(res)
      class(Factory0{U}), intent(in)  :: self
      class(IResolver),   intent(in)  :: c
      class(*),           allocatable :: res
      res = self%ctor()
   end function create0

   function create1(self, c) result(res)
      class(Factory1{T,U}), intent(in)  :: self
      class(IResolver),     intent(in)  :: c
      class(*),             allocatable :: res
      res = self%ctor(resolve{T}(c))
   end function create1

   function create2(self, c) result(res)
      class(Factory2{T1,T2,U}), intent(in)  :: self
      class(IResolver),         intent(in)  :: c
      class(*),                 allocatable :: res
      res = self%ctor(resolve{T1}(c), resolve{T2}(c))
   end function create2

end module FactoryMod
```

### 4.5 `ContainerMod.f90`

```fortran
module ContainerMod
   use, intrinsic :: generics, only: type_name
   use IResolverMod,  only: IResolver, resolve_trait => resolve
   use IFactoryMod,   only: initializer0, initializer1, initializer2
   use FactoryMod,    only: Factory0, Factory1, Factory2
   use FactoryMapMod, only: FactoryMap
   implicit none
   private
   public :: Container

   !...........................................................
   ! Dependency injection container for traits.
   ! Employs trait parameters and overloading of generic methods.
   !...........................................................
   type, implements(IResolver) :: Container
      private
      type(FactoryMap) :: factories
   contains
      generic   :: register => register0, register1, register2
      procedure :: register0, register1, register2
      procedure :: resolve_key
      procedure :: resolve
   end type Container

contains

   !.. registration for initializers taking no arguments
   subroutine register0{abstract interface :: P, P :: U}(self, ctor)
      class(Container), intent(inout) :: self
      procedure(initializer0{U})      :: ctor
      call self%factories%store(type_name{P}(qualified=.true.), Factory0{U}(ctor))
   end subroutine register0

   !.. registration for initializers taking one argument, of trait T
   subroutine register1{abstract interface :: P, abstract interface :: T, P :: U}(self, ctor)
      class(Container), intent(inout) :: self
      procedure(initializer1{T,U})    :: ctor
      call self%factories%store(type_name{P}(qualified=.true.), Factory1{T,U}(ctor))
   end subroutine register1

   !.. registration for initializers taking two arguments, of traits T1 and T2
   subroutine register2{abstract interface :: P, abstract interface :: T1, &
                        abstract interface :: T2, P :: U}(self, ctor)
      class(Container), intent(inout) :: self
      procedure(initializer2{T1,T2,U}) :: ctor
      call self%factories%store(type_name{P}(qualified=.true.), Factory2{T1,T2,U}(ctor))
   end subroutine register2

   !.. call the factory registered under key on this container,
   !.. which resolves its dependencies recursively
   function resolve_key(self, key) result(res)
      class(Container), intent(in)  :: self
      character(*),     intent(in)  :: key
      class(*),         allocatable :: res
      res = self%factories%create(key, self)
   end function resolve_key

   !.. Swift: c.resolve(P.self)
   function resolve{abstract interface :: P}(self) result(res)
      class(Container), intent(in)  :: self
      class(P),         allocatable :: res
      res = resolve_trait{P}(self)
   end function resolve

end module ContainerMod
```

`FactoryMapMod` is the present hash map, with its value changed from a
procedure pointer to a `class(IFactory), allocatable` component. Its
`store(key, factory)` copies the factory object. Its
`create(key, c)` looks up the entry, stops with an error if there is
none, and returns `entry%factory%create(c)`.

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
initializer of one argument. `Printer` and `Writer` have no components,
so their structure constructors `Printer()` and `Writer()` serve as
initializers (E3, rule 2), and they need nothing at all:

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

   type(Container)             :: cont
   class(IClient), allocatable :: cobj

   !.. register the initializers of the implementing types with the traits
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

### 4.8 What the compiler does for one registration

For `call cont%register{ILogger}(DoubleLogger)`:
1. **Resolve `register` (E6).** The non-generic specifics are tried
   first; there are none. Then each generic specific is tried:
   - `register0` and `register1` are not viable, because
     `DoubleLogger`'s initializer has 2 arguments.
   - `register2` is viable.
2. **Bind the explicit argument (E1, E5).** `P = ILogger` is given
   explicitly.
3. **Infer the rest (E3, E4).** `DoubleLogger` designates `init`.
   Matching `init` against `initializer2{T1,T2,U}` infers
   `T1 = IPrinter`, `T2 = IWriter` and `U = DoubleLogger`.
4. **Check the constraint (E2).** `ILogger :: DoubleLogger` holds, since
   `DoubleLogger` implements `ILogger`.
5. **Instantiate.** `register2{ILogger, IPrinter, IWriter, DoubleLogger}`
   is instantiated. Its body instantiates
   `Factory2{IPrinter, IWriter, DoubleLogger}`, whose `create2`
   instantiates `resolve{IPrinter}` and `resolve{IWriter}`.
   - `create2` is precisely the former hand-written
     `create_DoubleLogger`;
   - its two `select type` blocks are the instantiated bodies of
     `resolve`.

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
- **Lifetimes.** As for any procedure pointer, a factory must not
  capture an internal procedure whose host has returned. Initializers
  are module procedures, so this does not arise for E3.
- **Instance lifetime.** Each `resolve` creates new objects. Singletons
  and scoped lifetimes are a container design question, not a language
  one.

## 6. Open questions for review and outlook

**Open questions:**
1. **Spelling of trait parameters.** `{abstract interface :: P}` mirrors
   trait declarations but is verbose. Alternatives are
   `{interface :: P}`, or a predefined meta-trait `{ITrait :: P}` in
   the `generics` module.
2. **Overlap of generic specifics.** Should Swift's "more specialized"
   and "more constrained" ranking rules be adopted too? This proposal
   keeps Fortran's rule that overlapping specifics are a declaration
   error, except non-generic over generic.
3. **Implicit structure constructors as initializers (E3, rule 2).**
   This is useful (`Printer`, `Writer`) and parallels Swift's memberwise
   initializers. Alternatively only explicit initializers could be
   designated, which settles the proposal's open question on whether
   the implicit structure constructor counts as an initializer the
   other way.
4. **`type_name` result form.** Should the qualified form use
   `Module::Name`? Should letter case be preserved?

**Outlook:**
- **Variadic generics.** Swift 5.9 added parameter packs
  (`register<P, each T, U>(_: P.Type, _: (repeat each T) -> U)`), which
  reduce the three overloads to one. A Fortran analogue,
  `{abstract interface, dimension(*) :: T}`, would do the same here.
- **Default methods in traits.** Swift's protocol extensions could
  allow `resolve{P}` to be written once in `IResolver` and called as
  `c%resolve{T}()` on any trait object.
- **Meta-type values.** Storing types in variables, as Swift's `P.Type`
  allows, is not needed for DI. It would be a far larger extension.
