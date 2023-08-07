module poly_funcs
use, intrinsic :: iso_fortran_env, only: int64, real64
implicit none
private

    public :: average, simple_sum_int64, simple_sum_real64, pairwise_sum_int64, pairwise_sum_real64

    interface average
        module procedure average_int64
        module procedure average_real64
    end interface average

    interface simple_sum
        module procedure simple_sum_int64
        module procedure simple_sum_real64
    end interface simple_sum

    interface pairwise_sum
        module procedure pairwise_sum_int64
        module procedure pairwise_sum_real64
    end interface pairwise_sum

    contains

        pure function simple_sum_int64(x) result(s)
            integer(int64), intent(in) :: x(:)
            integer(int64) :: s, i
            s = 0_int64
            do i=1,size(x)
                s = s + x(i)
            end do
        end function simple_sum_int64

        pure function simple_sum_real64(x) result(s)
            real(real64), intent(in) :: x(:)
            real(real64) :: s
            integer(int64) :: i
            s = 0.0_real64
            do i=1,size(x)
                s = s + x(i)
            end do
        end function simple_sum_real64

        pure recursive function pairwise_sum_int64(x) result(s)
            integer(int64), intent(in) :: x(:)
            integer(int64) :: s, m
            if (size(x) <= 2) then
                s = simple_sum(x)
            else
                m = size(x)/2
                s = pairwise_sum(x(:m)) + pairwise_sum(x(m+1:))
            end if
        end function pairwise_sum_int64

        pure recursive function pairwise_sum_real64(x) result(s)
            real(real64), intent(in) :: x(:)
            real(real64) :: s
            integer(int64) :: m
            if (size(x) <= 2) then
                s = simple_sum(x)
            else
                m = size(x)/2
                s = pairwise_sum(x(:m)) + pairwise_sum(x(m+1:))
            end if
        end function pairwise_sum_real64

        pure function average_int64(sum_func_arg, x) result(s)
            interface
                pure function sum_func_interface(x) result(s)
                    import int64
                    implicit none
                    integer(int64), intent(in) :: x(:)
                    integer(int64) :: s
                end function sum_func_interface
            end interface
            procedure(sum_func_interface) :: sum_func_arg
            integer(int64), intent(in) :: x(:)
            integer(int64) :: s
            s = sum_func_arg(x)/size(x)
        end function average_int64

        pure function average_real64(sum_func_arg, x) result(s)
            interface
                pure function sum_func_interface(x) result(s)
                    import real64
                    implicit none
                    real(real64), intent(in) :: x(:)
                    real(real64) :: s
                end function sum_func_interface
            end interface
            procedure(sum_func_interface) :: sum_func_arg
            real(real64), intent(in) :: x(:)
            real(real64) :: s
            s = sum_func_arg(x)/size(x)
        end function average_real64

end module poly_funcs

program main
use, intrinsic :: iso_fortran_env, only: int64, real64, output_unit, input_unit
use, non_intrinsic :: poly_funcs, only: average, simple_sum_int64, simple_sum_real64, pairwise_sum_int64, pairwise_sum_real64
implicit none

    integer(int64) :: xi(5) = [1_int64, 2_int64, 3_int64, 4_int64, 5_int64], key, avi
    real(real64) :: xf(5) = [1.0_real64, 2.0_real64, 3.0_real64, 4.0_real64, 5.0_real64], avf

    write(output_unit,'(a)') 'simple_sum average: 1'
    write(output_unit,'(a)') 'pairwise_sum average: 2'
    write(output_unit,'(a)', advance='no') 'choose an averaging method: '
    read(input_unit,'(i1)') key 

    select case (key)
        case (1_int64)
            avi = average(simple_sum_int64, xi)
            avf = average(simple_sum_real64, xf)
        case (2_int64)
            avi = average(pairwise_sum_int64, xi)
            avf = average(pairwise_sum_real64, xf)
        case default
            error stop 'case not implemented'
    end select

    write(output_unit,'(i0)') avi
    write(output_unit,'(f0.1)') avf

end program main
