module printable_m
    implicit none

    abstract interface :: IPrintable
        subroutine output()
        end subroutine output
    end interface IPrintable

end module printable_m

! Library A: one implementation of IPrintable for real(real64)
module plain_m
    use, intrinsic :: iso_fortran_env, only: real64
    use printable_m, only: IPrintable
    implicit none

    implements IPrintable :: real(real64)
        procedure, pass :: output => plain_output
    end implements real(real64)

contains

    subroutine plain_output(self)
        real(real64), intent(in) :: self
        print "(a,f6.2)", "plain: ", self
    end subroutine plain_output

end module plain_m

! Library B: a different implementation for the same type
module fancy_m
    use, intrinsic :: iso_fortran_env, only: real64
    use printable_m, only: IPrintable
    implicit none

    implements IPrintable :: real(real64)
        procedure, pass :: output => fancy_output
    end implements real(real64)

contains

    subroutine fancy_output(self)
        real(real64), intent(in) :: self
        print "(a,es12.4,a)", "fancy: <<", self, ">>"
    end subroutine fancy_output

end module fancy_m

program two_impls
    use, intrinsic :: iso_fortran_env, only: real64
    implicit none

    real(real64) :: y

    y = 4.9_real64
    call print_plain(y)
    call print_fancy(y)

contains

    subroutine print_plain(x)
        use plain_m
        real(real64), intent(in) :: x
        call x%output()
    end subroutine print_plain

    subroutine print_fancy(x)
        use fancy_m
        real(real64), intent(in) :: x
        call x%output()
    end subroutine print_fancy

end program two_impls
