! Counterpart of two_impls_single.f90 under the plan in
! ../../most-restrictive-plan.md (proposal syntax, not standard Fortran).
! Each pair of a type and a trait has at most one implementation in a
! program, declared in the module that defines the trait or in the module
! that defines the type. The LFortran prototype does not implement this
! plan; see ../README.md.

module printable_m
    use, intrinsic :: iso_fortran_env, only: real64
    implicit none
    private

    public :: IPrintable

    abstract interface :: IPrintable
        subroutine output()
        end subroutine output
    end interface IPrintable

    ! real(real64) is an intrinsic type, so its implementation of IPrintable
    ! can only be declared here, in the module that defines IPrintable.
    implements IPrintable :: real(real64)
        procedure, pass :: output => plain_output
    end implements real(real64)

contains

    subroutine plain_output(self)
        real(real64), intent(in) :: self
        print "(a,f6.2)", "plain: ", self
    end subroutine plain_output

end module printable_m

module fancy_real_m
    use, intrinsic :: iso_fortran_env, only: real64
    use printable_m, only: IPrintable
    implicit none
    private

    public :: FancyReal

    ! A distinct type, not a second implementation for real(real64).
    type, sealed :: FancyReal
        real(real64) :: value
    end type FancyReal

    ! Allowed because this module defines FancyReal.
    implements IPrintable :: FancyReal
        procedure, pass :: output => fancy_output
    end implements FancyReal

contains

    subroutine fancy_output(self)
        type(FancyReal), intent(in) :: self
        print "(a,es12.4,a)", "fancy: <<", self%value, ">>"
    end subroutine fancy_output

end module fancy_real_m

program globally_unique
    use, intrinsic :: iso_fortran_env, only: real64
    ! The trait and the type only: plain_output and fancy_output are private.
    use printable_m, only: IPrintable
    use fancy_real_m, only: FancyReal
    implicit none

    real(real64) :: y
    type(FancyReal) :: f

    y = 4.9_real64
    f = FancyReal(y)
    call y%output()
    call f%output()
end program globally_unique
