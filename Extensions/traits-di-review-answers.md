# Answers to the review of the DI extension proposal

*Reply by the authors of
[traits-di-extension.md](traits-di-extension.md) to the questions in
Sect. 4.2 of [traits-di-review.md](traits-di-review.md), "Dependency on
the concrete function implementation `resolve`".*

## 0. Summary

Answering the review's questions showed us that Sect. 3.10 of the
proposal was wrong in one important respect. It claimed that a generic
message can be called through a trait object only if its type parameters
range over closed type sets. That is not so. The LFortran prototype
already dispatches generic messages with *open* type parameters through
trait objects, by passing the type argument's witness table at run time
(*dictionary passing*), which is the technique Swift uses. Appendix A
gives two programs that run on the prototype today, one of which has the
shape of the review's projected `IFactory`.

What is missing is narrower than Sect. 3.10 suggested. It is the case
where the type parameter of the generic message is a *trait* parameter
(E1), as in `resolve{Trait :: P}`. The dictionary of a trait argument
would be a small run-time descriptor of the trait. Every operation that
E1 allows on a trait parameter can be carried out with such a
descriptor, so we propose to add it as a new extension, **E10**. With
E10, `resolve` becomes a generic message of `IResolver` again, `c`
stays a trait object as in Swift, and the split into a message and a
free procedure disappears. No run-time instantiation and no
user-visible meta-types are needed.

| Question | Short answer |
|---|---|
| What is a "slot"? | One entry of a trait object's table of procedures, one per message (Sect. 1). |
| Is the issue caused by a generic message on a trait object? | Necessary but not sufficient. It also depends on what the type parameter ranges over: a closed type set or an open trait works today; a trait parameter does not yet (Sect. 2). |
| Do meta-types only help with run-time instantiation? | No. Swift does not instantiate code at run time either. It passes type information as hidden arguments, and so can Fortran, while keeping static instantiation (Sect. 3). |
| Can the Swift structure be kept with static instantiation? | Yes, with E10 (Sect. 4). |
| Protocol extensions? | They would give `c%resolve{T}()` syntax for the existing split, but no new semantics (Sect. 5). |
| Compile-time polymorphism for `c`? | It moves the trait object instead of removing it, and needs E10 as well (Sect. 6). |
| Does `Factory`'s `box` cause the same issue? | Yes, it is one of the places where the generic message is dispatched at run time (Sect. 7). |
| Parameterized traits? | Yes, they would make the whole container static except for the map lookup, at the price of a larger extension (Sect. 8). |

## 1. What is a "slot"?

A trait object, such as a `class(IResolver)` variable, is a pair of two
pointers:

- a pointer to the data of the object;
- a pointer to a table that the dynamic type provides for the trait.

The table has one entry per message of the trait. Each entry holds the
address of the procedure that implements that message for the dynamic
type. These entries are what Sect. 3.10 called *slots*. Other languages
call the same table a vtable (C++), a witness table (Swift), an itable
(Go) or a vtable of a `dyn` trait (Rust). In the prototype it is the
trait's *runtime contract*.

A call `c%resolve_key(key)` loads the slot of `resolve_key` from `c`'s
table and calls the procedure found there, passing `c`'s data pointer
as `self`.

The table is filled where a value of a concrete type first becomes a
trait object, for example where a `type(Container)` is passed to a
`class(IResolver)` dummy. Each slot must hold *one* procedure, and its
address must be known at that point.

This is where generic messages become difficult. With static
instantiation, a generic procedure is not one procedure but a family,
one instance per tuple of type arguments. `Container`'s `resolve{P}`
becomes `resolve{IClient}`, `resolve{IPrinter}`, and so on. When the
table is filled, the compiler does not know which instances later
callers will ask for. A caller in a module compiled years later may
call `c%resolve{INewTrait}()`. So there is no finite set of procedures
to put into the table. There are two ways to fill the slot all the same:

1. **One slot per instance.** If the set of possible type arguments is
   finite and fixed when the trait is declared, the table gets one slot
   per member of the set. This is the case for closed type sets such as
   `{integer | real(real64) :: T}`.
2. **One erased slot.** The slot holds a single procedure that is
   compiled once, without knowing the type argument, and receives the
   type argument as a hidden run-time argument, its *dictionary*. For a
   type parameter constrained by a trait, the dictionary is the type's
   table for that trait. The body then calls the trait's messages on its
   type-parameter values through this table. This is dictionary passing.

The prototype implements both. Sect. 3.10 overlooked the second.

## 2. Is the issue caused by `c` being a trait object with a generic message?

It is a necessary condition, but not a sufficient one. A generic message
that is called on a statically known type is simply instantiated
statically, and nothing about it is unusual. Only a call through a trait
object needs a slot.

Whether such a slot can be filled depends on what the type parameter of
the message ranges over:

| Type parameter | Example | Slot | Prototype |
|---|---|---|---|
| Closed type set | `{integer \| real(real64) :: T}` | one per member | works (`traits_runtime_numeric_01`) |
| Open, constrained by a trait | `{IShow :: T}` | one erased slot; the dictionary is `T`'s table for `IShow` | works (`traits_runtime_generic_02`, Appendix A) |
| A trait (E1) | `{Trait :: P}` | one erased slot; the dictionary would be a descriptor of the trait | not designed yet, proposed as E10 (Sect. 4) |

So the issue is not caused by the generic message as such, but by its
parameter being a *trait* parameter, for which no dictionary had been
designed.

The prototype restricts the open case in some ways. For example, the
erased body may do only what the dictionary describes with a value of
the erased type. These restrictions do not matter for DI, because the
DI container only passes trait objects around.

**Closed and open sets.** A set of admissible type arguments is *closed*
if it is finite and fixed where the constraint is declared. A type set
such as `real | real(real64) | complex` is closed. It is *open* if new
admissible types can be added later without changing the constraint. A
trait is open, because any type, written later anywhere, can implement
it.

This is independent of intrinsic versus user-defined types. A type set
may list derived types, and an intrinsic type may implement an open
trait through an `implements` statement. The two only correlate because
type sets are the usual way to write constraints over intrinsic types.

## 3. Do meta-types help only together with run-time instantiation?

No, and this is good news for the design. The statement rests on the
premise that Swift instantiates generics at run time. It does not
generate code at run time.

- **Unspecialized code:** Swift compiles a generic function once. The
  type metadata of each type parameter, and the witness table of each
  conformance it needs, are passed to the function as hidden arguments.
  This is the dictionary passing of Sect. 1.
- **Specialization:** generating one instance per type argument, as
  Fortran does, is an optimization that the Swift optimizer applies
  when it sees the type arguments at compile time.
- **What happens at run time:** the Swift runtime does build *metadata*
  for instances of generic types lazily, for example for
  `Factory1<IPrinter, DoubleLogger>`, but it never generates *code*.

So what the Swift version needs is not run-time instantiation, but the
ability to compile a generic message once, in erased form, and to pass
its type argument at run time. User-visible meta-type values are
neither necessary nor sufficient for that. They are only the Swift
*syntax* through which the user passes the type argument; Fortran
passes it in braces, `c%resolve{IClient}()`.

Fortran's static instantiation model can be kept. The compiler then
generates code for a generic message in two forms:

- **Static instances:** wherever the type arguments are known at
  compile time, the generic message is instantiated statically, exactly
  as now. This includes every call on a non-polymorphic object, such as
  `cont%resolve{IClient}()` on `type(Container)`.
- **One erased copy:** only for the slot of a trait object's table. It
  is generated once, in the module that implements the message.

The prototype already works this way for open type parameters
constrained by traits.

## 4. Can the Swift structure be kept, with static instantiation? (E10)

Yes. We propose a tenth extension.

**E10: trait parameters in runtime generic messages.** A generic message
whose type parameters include trait parameters (E1) may be called
through a trait object. The dictionary of a trait argument is a *trait
descriptor*: a constant record, one per trait, that holds the trait's
name and its identity for run-time conformance queries.

Every use of a trait parameter `P` that E1 allows can be carried out in
an erased body with only the descriptor:

- **`class(P)` declarations:** a trait object has the same
  representation for every trait, a data pointer and a table pointer.
  Its size and layout do not depend on `P`.
- **`select type ... class is (P)`:** this is the run-time conformance
  query that `class is (ILogger)` already performs, with the trait
  supplied by the descriptor instead of as a constant. The query yields
  the dynamic type's table for `P`.
- **Assigning to a `class(P)` result:** pair the data pointer with the
  table found by the query.
- **`type_name{P}()`:** read the name from the descriptor.
- **Passing `P` on:** pass the descriptor on.

`type(P)` is not allowed by E1, so no layout of `P` is ever needed. This
makes trait parameters the *easiest* kind of type parameter to erase.
Unlike type parameters, they need no restrictions on what the erased
body may do.

With E10, the container keeps the structure of the Swift original:

```fortran
abstract interface :: IResolver
   function resolve{Trait :: P}(self) result(res)
      type(itself), pass, intent(in) :: self
      class(P),           allocatable :: res
   end function resolve
end interface

abstract interface :: IFactory
   function create(self, c) result(res)
      type(itself), pass, intent(in)  :: self
      class(IResolver),   intent(in)  :: c
      class(*),           allocatable :: res
   end function create
end interface
```

```fortran
function create1(self, c) result(res)
   type(Factory1{T1,U}), intent(in)  :: self
   class(IResolver),     intent(in)  :: c
   class(*),             allocatable :: res
   res = self%ctor(c%resolve{T1}())     ! Swift: ctor(c.resolve(T1.self))
end function create1
```

`Container` implements `resolve` once, as in the review's projected
`ContainerMod`:

```fortran
function resolve{Trait :: P}(self) result(res)
   type(Container), intent(in)  :: self
   class(P),        allocatable :: res
   class(IFactory), allocatable :: fact
   key := type_name{P}(qualified=.true.)
   call self%factories%retrieve(key, fact)
   select type (obj => fact%create(self))
   class is (P)
      res = obj
   class default
      error stop "No registration available for " // type_name{P}()
   end select
end function resolve
```

For this program the compiler generates:

- **Static instances** of `Container`'s `resolve` for the calls on
  `type(Container)`, such as `resolve{IClient}` for
  `cont%resolve{IClient}()` in the main program.
- **One erased `resolve`** in `ContainerMod`, which takes a hidden trait
  descriptor and is placed in the `resolve` slot of `Container`'s table
  for `IResolver`.
- **At each call `c%resolve{T1}()`** in an instance such as
  `Factory1{IPrinter, Printer}`'s `create1`: a load of the slot and a
  call with the descriptor of `IPrinter`, which is a compile-time
  constant there.

Because `Container` is `sealed`, a compiler that can prove the dynamic
type of `c` may still call the static instance directly.

**Dependencies.** `FactoryMod` depends only on `IResolverMod` and
`IFactoryMod`. `ContainerMod` depends on `FactoryMod`, as
`Container.swift` imports `Factory`. There is no free `resolve`
procedure.

**Cost at run time.** The `class is (P)` query and the call through the
table are the same work that Swift's `as? P` and its witness-table call
do. The split design of Sect. 3.10 performs the same query as well,
inside the free `resolve`.

**Relation to the split of Sect. 3.10.** We would keep the split only as
a fallback that works without E10. As to coupling, even the split does
not depend on an *implementation* in the sense of the Dependency
Inversion Principle. The free `resolve{P}(c)` lives in `IResolverMod`,
next to the trait, and depends only on the trait. It is part of the
abstraction's published interface, like a Swift protocol extension
method or C++'s non-virtual interface idiom. What it does cost is the
following:

- an implementer of `IResolver` cannot customize `resolve{P}`;
- the trait has to expose the stringly-typed `resolve_key` message and
  its `class(*)` result;
- the free procedure has to be imported, and is renamed in
  `ContainerMod`.

E10 removes all three.

## 5. Protocol extensions

In Swift, an extension of a protocol adds methods *with bodies* to the
protocol:

```swift
extension IResolver {
    func resolve<P>(_ protocolType: P.Type) -> P {
        let key = String(describing: protocolType)
        return resolveKey(key) as! P
    }
}
```

Every conforming type and every existential `any IResolver` gets the
method, so `c.resolve(IClient.self)` works on any `c`. If the method is
not also a *requirement* of the protocol, it is statically dispatched.
It is compiled once per protocol, not per conforming type, and a
conforming type cannot override it. This is the well-known Swift pitfall
where a method of the same name in a conforming type is silently
ignored when the object is used through the protocol.

A Fortran analogue would let a trait carry procedures with bodies, which
may call only the trait's messages, for example:

```fortran
abstract interface :: IResolver
   function resolve_key(self, key) result(res)
      type(itself), pass, intent(in)  :: self
      character(*),       intent(in)  :: key
      class(*),           allocatable :: res
   end function resolve_key
contains
   function resolve{Trait :: P}(self) result(res)   ! a method with a body
      class(IResolver), intent(in)  :: self
      class(P),         allocatable :: res
      select type (obj => self%resolve_key(type_name{P}(qualified=.true.)))
      class is (P)
         res = obj
      end select
   end function resolve
end interface
```

`c%resolve{IClient}()` would then work on every `class(IResolver)`
object and every type that implements `IResolver`. But this is exactly
the split of Sect. 3.10 in a different package:

- `resolve` is still statically instantiated per trait;
- it still calls the non-generic message `resolve_key`;
- the string key and the `class(*)` result remain.

It removes the free procedure and gives method syntax, so it answers the
*encapsulation* concern, but not the coupling or flexibility concerns.
Swift also lets a protocol extension supply a *default implementation*
of a requirement. That one is dynamically dispatched and can be
overridden, but for a generic requirement it needs exactly the
mechanism of E10.

Protocol extensions are therefore a useful extension in their own right,
but E10 is what restores the Swift semantics.

## 6. Compile-time polymorphism for `c`

The review's
[projected branch](https://github.com/difference-scheme/FortranDIContainer/tree/projected)
declares `c` as `type(Resolver)`, with `Resolver` a type parameter of
the generic message `create{IResolver :: Resolver}` of `IFactory`. This
is also what the closure-less Swift version does, with
`func create<Resolver: IResolver>(_ c: Resolver) -> Any`.

But `create` is itself called through trait objects. This happens in
`Factory`'s `self%box%create(c)` and in `ContainerMod`'s
`fact%create(self)`, both on `class(IFactory)` objects. So `create`
becomes a runtime generic message with an open type parameter
`Resolver`, and its slot must hold an erased `create`. The dictionary of
`Resolver` is its table for `IResolver`, so inside the erased body
`type(Resolver)` is represented exactly as `class(IResolver)` is: a data
pointer and a table pointer. Compile-time polymorphism therefore does
not remove the trait object. It moves the type erasure from `c` into
the dictionary of `create`.

The prototype confirms the first step (Appendix A.1). A generic message
`create{IResolver :: Resolver}(self, c)`, called through a
`class(IFactory)` trait object, runs correctly today.

The second step is `c%resolve{T1}()` inside the erased `create1`. Here
`c` is of the erased type `Resolver`, so this call goes through the
dictionary of `Resolver`, which needs a slot for the generic message
`resolve{Trait :: P}`. That is E10 again. In addition, the prototype
does not yet allow a constraint trait that itself contains generic
messages: "generic methods in generic type parameter constraints are
not implemented yet". That is a gap in the prototype, not in the design.

Swift compiles the closure-less version with exactly these two
mechanisms. It passes `Resolver`'s witness table to the unspecialized
`create`, and `T1`'s metadata to `resolve`.

So the projected design needs E10 as well, and in addition generic
messages in constraint traits. It is not more loosely coupled than the
E10 design of Sect. 4:

- in both, `FactoryMod` depends only on the traits;
- in both, `ContainerMod` depends on `FactoryMod`.

The E10 design is simpler and is honest about where dynamic dispatch
happens. The projected design is not wrong, though; with the prototype's
dual compilation model and E10 it would compile and run. A static
`Resolver` only pays off when the type erasure happens after `Resolver`
is fixed, which is the subject of Sect. 8.

## 7. `Factory`'s `box` component

Yes. `self%box%create(c)` is a call of the generic message `create`
through a `class(IFactory)` trait object, so it is one of the two places
described in Sect. 6. Today it works for an open `Resolver` (Appendix
A.1). The nested `c%resolve{T1}()` is what needs E10.

Some type erasure is unavoidable in a DI container, because its map
holds factories of many different types under one element type. Swift
erases the same way with `any IFactory` and `Any`.

Notice that with E8 and E9 the decorator `Factory` erases twice:

- the map stores `class(IFactory)`;
- `Factory` holds another `class(IFactory)` in `box`.

This costs one more indirect call per resolution, which is negligible.
The decorator exists to give the user a single name `Factory(ctor)` for
three types, which we agree is worth having.

## 8. Generically parameterized traits

Yes. This is how Rust and Go avoid the problem.

- **Rust:** a trait with a generic method is not *dyn-compatible*
  ("object safe"), so it cannot be used as `dyn Trait`. This rule exists
  for exactly the reason of Sect. 1. The idiom is to move the parameter
  from the method to the trait, `trait Factory<R: Resolver>`, and to
  store `Box<dyn Factory<Container>>`.
- **Go:** methods cannot have type parameters at all, only types and
  interfaces can.

In Fortran this would read:

```fortran
abstract interface :: IFactory{IResolver :: Resolver}
   function create(self, c) result(res)
      type(itself), pass, intent(in)  :: self
      type(Resolver),     intent(in)  :: c
      class(*),           allocatable :: res
   end function create
end interface
```

The map then stores `class(IFactory{Container})`. Now `create` is not
generic, so its slot holds one procedure. Inside `create1`, the type
`Resolver` is the statically known `Container`, so `c%resolve{T1}()` is
a static call of `Container`'s `resolve{T1}`, statically instantiated
as well. `IResolver` is then used only as a constraint and never as a
trait object.

The whole container becomes static except for the lookup in the map,
which is the one place where a heterogeneous collection makes dynamic
dispatch unavoidable. Of all the variants, this one fits Fortran's
static model best.

Its price:

- **A new kind of generic entity.** Sect. "Traits with generic procedure
  signatures" of the main proposal argues against parameterized traits, for usability.
  Parameterized trait objects would be needed in addition to
  parameterized traits as constraints.
- **A self-referential instantiation.** `Container` has a component
  whose element type, `class(IFactory{Container})`, mentions `Container`
  itself, which must be instantiated while `Container` is being
  defined. This should be possible, much as a derived type may have
  allocatable components of its own type, but it needs to be specified.
- **One resolver type per container.** All factories registered with
  one container must agree on the `Resolver` type, which is natural for
  a container.

An alternative within the present proposal would be an associated type
`Resolver` of `IFactory`, with trait objects whose associated types are
fixed, `class(IFactory(Resolver=Container))`. This corresponds to
Rust's `dyn Factory<Resolver = Container>`. The prototype has
associated types for constraints; we have not yet evaluated them in
trait objects.

**Our recommendation.**

- **E10:** adopt it for the DI container. It is small, it adds no new
  kind of generic entity, it reuses the prototype's existing
  dictionary-passing machinery, and it restores the Swift structure
  exactly.
- **Parameterized traits or associated types in trait objects:**
  consider them separately, as a broader extension with uses beyond DI.

## 9. Changes to the proposal

We will update [traits-di-extension.md](traits-di-extension.md)
accordingly. This pull request already corrects the wrong statement in
its Sect. 3.10. A follow-up will:

- add the review's E8 and E9 (generic initializers and their
  overloading), together with E10;
- replace the split of Sect. 3.10 and Sect. 4 by the E10 design, keeping
  the split as a fallback without E10;
- adopt the answers of Sect. 5 of the review: `Trait` and `AnyType`,
  structure constructors as initializers, and Fortran's overlap rules.

## Appendix A. Programs that run on the LFortran prototype

Both programs compile and run with LFortran's traits prototype (branch
`traits_06` of `certik/lfortran`, commit `663942ee20`). They use an open
type parameter constrained by a trait, because trait parameters (E1)
are not implemented yet.

### A.1 A generic message with an open type parameter through a trait object

This is the shape of the review's projected `IFactory`. The generic
message `create{IResolver :: Resolver}` is called on a
`class(IFactory)` trait object. Its `error stop` check passes.

```fortran
module m
   implicit none
   abstract interface :: IResolver
      integer function resolve_key(self, key)
         type(itself), intent(in), pass :: self
         integer, intent(in) :: key
      end function
   end interface
   abstract interface :: IFactory
      integer function create{IResolver :: Resolver}(self, c)
         type(itself), intent(in), pass :: self
         type(Resolver), intent(in) :: c
      end function
   end interface
   type :: Container
      integer :: base = 100
   end type
   implements IResolver :: Container
      procedure, pass :: resolve_key => container_resolve_key
   end implements
   type :: Factory1
      integer :: dep = 7
   end type
   implements IFactory :: Factory1
      procedure, pass :: create => create1
   end implements
contains
   integer function container_resolve_key(self, key) result(r)
      type(Container), intent(in) :: self
      integer, intent(in) :: key
      r = self%base + key
   end function
   integer function create1{IResolver :: Resolver}(self, c) result(r)
      type(Factory1), intent(in) :: self
      type(Resolver), intent(in) :: c
      r = c%resolve_key(self%dep)
   end function
end module

program p
   use m
   implicit none
   class(IFactory), allocatable :: box
   type(Container) :: cont
   box = Factory1()
   if (box%create(cont) /= 107) error stop 1
end program
```

### A.2 The Swift structure: a generic message of the resolver, called on a trait object

This is the structure of Sect. 4, with `c` a `class(IResolver)` trait
object and `resolve` a generic message of `IResolver`. The only
difference to Sect. 4 is the kind of `resolve`'s type parameter: here an
open type parameter `{IShow :: T}`, there a trait parameter
`{Trait :: P}`, which needs E10. Its `error stop` check passes.

```fortran
module m
   implicit none
   abstract interface :: IShow
      integer function code(self)
         type(itself), intent(in), pass :: self
      end function
   end interface
   abstract interface :: IResolver
      integer function resolve{IShow :: T}(self, x)
         type(itself), intent(in), pass :: self
         type(T), intent(in) :: x
      end function
   end interface
   abstract interface :: IFactory
      integer function create(self, c)
         type(itself), intent(in), pass :: self
         class(IResolver), intent(in) :: c
      end function
   end interface
   type :: Dep
      integer :: v = 5
   end type
   implements IShow :: Dep
      procedure, pass :: code => dep_code
   end implements
   type :: Container
      integer :: base = 100
   end type
   implements IResolver :: Container
      procedure, pass :: resolve => container_resolve
   end implements
   type :: Factory1
      type(Dep) :: d
   end type
   implements IFactory :: Factory1
      procedure, pass :: create => create1
   end implements
contains
   integer function dep_code(self) result(r)
      type(Dep), intent(in) :: self
      r = self%v
   end function
   integer function container_resolve{IShow :: T}(self, x) result(r)
      type(Container), intent(in) :: self
      type(T), intent(in) :: x
      r = self%base + x%code()
   end function
   integer function create1(self, c) result(r)
      type(Factory1), intent(in) :: self
      class(IResolver), intent(in) :: c
      r = c%resolve(self%d)
   end function
end module

program p
   use m
   implicit none
   class(IFactory), allocatable :: box
   type(Container) :: cont
   box = Factory1(Dep())
   if (box%create(cont) /= 105) error stop 1
end program
```

Replacing `class(IResolver)` by `type(Resolver)` with
`create{IResolver :: Resolver}` in this program, as in the projected
branch, is rejected today with "generic methods in generic type
parameter constraints are not implemented yet" (Sect. 6).
