module mono_funcs
use, intrinsic :: iso_fortran_env, only: int64
implicit none
private

    public :: simple_average, pairwise_average

    contains

        pure function simple_sum(x) result(s)
            integer(int64), intent(in) :: x(:)
            integer(int64) :: s, i
            s = 0_int64
            do i=1,size(x)
                s = s + x(i)
            end do
        end function simple_sum

        pure recursive function pairwise_sum(x) result(s)
            integer(int64), intent(in) :: x(:)
            integer(int64) :: s, m
            if (size(x) <= 2) then
                s = simple_sum(x)
            else
                m = size(x)/2
                s = pairwise_sum(x(:m)) + pairwise_sum(x(m+1:))
            end if
        end function pairwise_sum

        pure function simple_average(x) result(s)
            integer(int64), intent(in) :: x(:)
            integer(int64) :: s
            s = simple_sum(x)/size(x)
        end function simple_average

        pure function pairwise_average(x) result(s)
            integer(int64), intent(in) :: x(:)
            integer(int64) :: s
            s = pairwise_sum(x)/size(x)
        end function pairwise_average

end module mono_funcs

program main
use, intrinsic :: iso_fortran_env, only: int64, output_unit, input_unit
use, non_intrinsic :: mono_funcs, only: simple_average, pairwise_average
implicit none

    integer(int64) :: xi(5) = [1_int64, 2_int64, 3_int64, 4_int64, 5_int64], key

    write(output_unit,'(a)') 'simple_sum average: 1'
    write(output_unit,'(a)') 'pairwise_sum average: 2'
    write(output_unit,'(a)', advance='no') 'choose an averaging method: '
    read(input_unit,'(i1)') key 

    select case (key)
        case (1_int64)
            write(output_unit,'(i0)') simple_average(xi)
        case (2_int64)
            write(output_unit,'(i0)') pairwise_average(xi)
        case default
            error stop 'case not implemented'
    end select

end program main
