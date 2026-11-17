# On the draft proposal "Traits extension: overloaded generic procedures and initializer reflection"

## 1. Overview

The above proposal is probably best summarized as aiming to extend the
presently implemented LFortran traits prototype with

1. overloading of generic procedures (which it presently lacks), and
2. further type inference capabilities (for function-typed arguments,
in particular initializers).

The proposed features are motivated by a comparison of an example
dependency injection (DI) container, written in the present LFortran
language dialect, to a more powerful Swift counterpart, and the impact
that both of these have on corresponding versions of an application
code that makes use of them. Relative to this application's Swift
implementation, its version that is written in the present LFortran
dialect still exhibits large amounts of boilerplate code, and hence
demonstrates the need for further language improvements.

The proposal is generally well written, with good explanations. In
total, seven well researched minor extensions (E1-E7) to facilities
that are already available in the prototype are proposed. Several of
these extensions (e.g. traits as parameters/arguments to generics
(E1), generic *unnamed* abstract interfaces (E4), partially explicit
type arguments to generics (E5), and overloading of generic procedures
(E6)) are either useful on their own to enable further use cases, or
are necessary for the prototype to attain internal consistency with
other features that it already supports. Hence, I think they would
have to be implemented regardless, i.e. independently of DI.

In this spirit, I recommend, below, to complete the type inference and
overloading features of the proposal by two further minor extensions
(generic initializers (E8), and their overloading (E9)), which I
believe would make its implementation even more valuable.


## 2. Deviations from the Swift design

The proposal gives the anticipated future Fortran code (once
the extensions E1-E7 are implemented) of

1. the example application (that makes use of the considered DI container),
2. but also that of the container itself.

Hence, the quality of the projected Fortran code of *both* of these parts
will be examined below.

To achieve its objectives using a minimal amount of new features, the
proposal makes two deviations from (or simplifications to) the
corresponding Swift examples:

- It replaces closures by objects.

- It also avoids introducing meta-types into Fortran, and instead
  passes traits as compile-time (rather than run-time) parameters,
  through generic parameter lists (see Sect. 3).

In general, I tend to agree with these choices (as an introduction of
these two rather large, omitted, features doesn't appear to be
necessary for the present purposes). But I have some questions to the
authors that are meant to aid my understanding of the differences of
the DI container's projected Fortran code relative to the Swift
version (that seem to be partly a consequence of some feature
omissions in the original Traits for Fortran proposal, but also a
result of the adjustments that are made in Sect. 3.10 of the present
proposal).

## 3. The projected application code

When it comes to the projected application code, the design fully
accomplishes the desired goals: namely, getting rid of all the
hand-coded factory functions (one per derived type) that are required
in the present Fortran version, with all their `select type`
statements, and the use of strings for registering dependencies, that
lack any checks. The achieved savings in boilerplate code scale with
code size, and can be massive. This is accomplished without any
changes to the application's derived types, and most importantly the
dependencies that they import. These continue to be *exclusively
traits*, as they should be in a plugin architecture.

Also, writing in the expected Fortran version of the application's main
program,

```
call cont%register{IClient}(Client)
call cont%register{ILogger}(DoubleLogger)
call cont%register{IPrinter}(Printer)
call cont%register{IWriter}(Writer)

cobj = cont%resolve{IClient}()
call cobj%log()
```

instead of the Swift version's exclusive use of run-time arguments

```
c.register(IClient.self,  Client.init)
c.register(ILogger.self,  DoubleLogger.init)
c.register(IPrinter.self, Printer.init)
c.register(IWriter.self,  Writer.init)

let client = c.resolve(IClient.self)
client.log()
```

makes little difference to the application developer. As the
dependencies of the "composition root" (i.e. the main program that
resolves the object graph) remain unaffected in both cases (as they
should).

## 4. The projected DI container code

When comparing the projected Fortran code for the example DI container
to the corresponding Swift version, I noticed that it is harder to
read, and that it has acquired some undesirable dependencies on
concrete implementation code.

Consider the original `Container.swift` module. This module has three
dependencies, namely on two protocols, `IResolver` and `IFactory`, and
one concrete implementation, `Factory`:


```
import IResolver
import IFactory
import Factory
```

On the other hand, the corresponding expected Fortran code
`ContainerMod.f90` has (among other things) dependencies on an
`IResolver` interface, three `initializer` interfaces (which
correspond to inline code in Swift), and a concrete `FactoryMap` (due
to present Fortran's lack of language provided hash maps, like Swift's
dictionaries):

```
use IResolverMod,  only: IResolver, resolve_trait => resolve
use IFactoryMod,   only: initializer0, initializer1, initializer2
use FactoryMod,    only: Factory0, Factory1, Factory2
use FactoryMapMod, only: FactoryMap

```

But even if one excludes all of these aforementioned dependencies, as
one should for a fair comparison, one is furthermore left with
dependencies on three different concrete `Factory` types, as well as
an unencapsulated concrete procedure, `resolve`. (In object-oriented
code, the latter could be regarded as a code-smell.)

To investigate why this is the case, I have
[rewritten](https://github.com/difference-scheme/DIContainer/tree/noclosure)
the original Swift DI container to replace its `create` closure by
objects, so that a more direct comparison between it and the
anticipated Fortran version can be made, and will thus offer some
conclusions from this exercise.

### 4.1 Dependencies on multiple Factory implementations

The need for multiple `Factory` types in the porposal's projected
Fortran version appears to be caused by the replacement of the
constructor-capture- and type-erasure-capabilities of the original
closure, `create`, by objects -- given that the [closure-less Swift
code version](https://github.com/difference-scheme/DIContainer/tree/noclosure)
exhibits the very same need.

The latter version also requires three Factory types (or "Boxes"), one
per arity of the constructors that need to be captured and
type-erased. In actual production code these could be many more than
just three. A redeeming feature of the closure-less Swift version,
though, is that these three types can still be hidden behind a single
`Factory` decorator type, by continuing to make use of Swift generic
initializers for this type (i.e. `struct`) and their overloading
capabilities:

```
public init<U>(...) {...}        // for calling Factory0(...)
public init<T1,U>(...) {...}     // for calling Factory1(...)
public init<T1,T2,U>(...) {...}  // for calling Factory2(...)
```
Both the original Traits for Fortran proposal, and the present proposal,
lack

1. such Swift-like initializers with their own generic type parameters
(feature E8),
2. as well as overloading of these generic initializers (feature E9),

which does not allow one to write an equivalent to the single
`Factory` of the Swift code. I believe this fact is also responsible,
in the present proposal's projected Fortran version, for the need to
instantiate its different Factory types by passing explicit generic
type parameters to their initializers,

```
call self%factories%store(type_name{P}(qualified=.true.), Factory0{U}(ctor))
call self%factories%store(type_name{P}(qualified=.true.), Factory1{T,U}(ctor))
call self%factories%store(type_name{P}(qualified=.true.), Factory2{T1,T2,U}(ctor))
```

instead of merely handing the `ctor` ordinary argument to a (generic)
initializer of a single `Factory` (decorator) type, and letting *it*
deal with inferring these parameters, as it is possible in the Swift
version:

```
let key = String(describing: protocolType)
factories[key] = Factory(ctor)
```

Which is a part of the reason why the Fortran version feels cluttered.

I would therefore suggest to the authors to extend the proposal by
the two missing features E8 and E9 that I listed in this Section, as
this is a gap in the present implementation of the LFortran traits
prototype that will have to be closed regardless, for consistency
reasons (it would be inconsistent to implement overloading for generic
methods, E6, but not to have overloadable generic initializers of
derived types).


### 4.2 Dependency on the concrete function implementation `resolve`

As I've mentioned above, there's a further undesirable dependency
present in the Fortran DI container's code, namely that on the
concrete procedure `resolve`. The reason that this is undesirable is
the tight coupling that dependencies on concrete implementation code
cause.  The Swift code version has a dependency on an `IResolver`
protocol for this very reason, i.e. for avoiding such tight coupling.

I had difficulty fully understanding Section 3.10 of the proposal that
explains the reasoning behind the authors' splitting of the original
`resolve` method into both a method and a regular parameterized
procedure.

- Could the authors explain what they mean by "slot" in this Sect. 3.10?

- Is the issue, that they work around in Sect. 3.10, caused by
  `c` being a trait object that contains a generic method? Or is this
  not a sufficient condition for this issue to surface, with the latter
  being also determined by which types actually implement the
  corresponding trait (e.g. intrinsic vs. user-defined ones). Is this
  what the authors mean by closed and open sets?

- Is it correct to state that the introduction of meta-types into
  Fortran, and the passing of type metadata via run-time arguments,
  would not change the need to split the aforementioned `resolve`
  method, *unless* Swift's instantiation model is also adopted and
  instantiation of generics at run-time is allowed?

- In case the latter statement is correct, could the original Swift
  way of coding the example (with `c` an existential) be still
  preserved, in order to maintain the loose coupling of the original
  version, but using Fortran's static generics instantiation model
  instead?

- The authors themselves seem to suggest a possible alternative in
  which "Swift’s protocol extensions could allow `resolve{P}` to be
  written once in `IResolver` and called as `c%resolve{T}()` on any
  trait object." Could they elaborate?

- If one sticks to the present prototype design that foregoes
  meta-types and protocol extension methods, would it be possible,
  as another alternative, to maintain the original loose
  coupling by replacing the trait object declaration of the
  `class(IResolver)` object `c` by compile-time polymorphism?

- To illustrate what I mean, I provide a
  [translation](https://github.com/difference-scheme/FortranDIContainer/tree/projected)
  (in the `projected` branch of the FortranDIContainer repository) of
  the "closure-less" Swift code version into what I believe the final
  Fortran code should look like to be loosely coupled.  Object `c` is
  now no longer a trait object, but is declared using
  generics. (Notice, that this code makes use of features E8-E9, and
  the recommendations of the next Sect. 5.)

- The `Factory` decorator type in this Fortran version presently uses
  a `box` variable that is declared as a trait object. Would
  this declaration also lead to similar issues?

- As a further alternative, could situations like this be completely
  avoided by introducing generically parameterized traits (as in Rust
  or Go) into Fortran so that trait object methods could make use of
  generic parameters without these methods having to be generic
  themselves?

## 5. Replies to the "Open questions for review"

In its Sect. 6, the proposal lists some open questions for review. My
suggestions for these are the following:

### 5.1 Spelling of trait parameters

Both `abstract interface` and `interface`, as names for the
constraints, are too long and, hence, unwieldy. They lead to
unreadable code. To me, the only viable choice appears to be the
introduction of a predefined meta-trait, `Trait`, so that one can
write, for example, `{Trait :: P}`. Here, `Trait` needs to be spelled
without an `I` prefix (since the meta-constraint itself is not an
interface). The meta-type `IAnyType` should also be renamed to read
`AnyType` from now on. This would bring both names closer to what
other languages (Rust, Mojo) use as names for these entities. The `I`
prefix, or in fact any other prefix for interfaces/traits, should
better be left for adoption as a convention by the user.

Both `Trait` and `AnyType` should be implicitly known in all
scoping units (like Fortran's intrinsic types, or intrinsic procedures,
are). It would be impractical having to import them every time
from the intrinsic `generics` module. As a remark in this context, the
(to be renamed) identifier `IAnyType` seems to be unsupported in the
LFortran prototype, as I can neither access it via the `generics`
module, nor does it seem to be implicitly known to the language.

Given that from now on multiple items (i.e. both traits and types)
will be passed as parameters to generics, it should be evaluated
whether it still makes sense to stick to the old implicit rule that
any unconstrained generic parameters are inferred to be constrained by
`AnyType`. The alternative would be to always have the programmer
provide all constraints explicitly. This would actually be a breaking
change: the `Vector` example of the original proposal would have to be
adjusted (along with any other tests that make use of this rule). A
decision regarding this point could be made after the proposal is
implemented.

### 5.2  Overlap of generic specifics

I'd suggest to keep Fortran's rules, as it was argued in the proposal,
as long as extensions of these are not required.

### 5.3 Implicit structure constructors as initializers (E3, rule 2)

Yes, structure constructors should count as initializers. As
the proposal itself points out, this is useful (e.g. for the types
`Printer`, and `Writer`).

### 5.4 `type_name` result form

I have no particular preference here (the present application should
work regardless of which particular qualified form is chosen,
including its letter case). This issue should best be decided later
on, after further experience with the prototype has been gathered.

