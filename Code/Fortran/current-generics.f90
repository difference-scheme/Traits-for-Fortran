module funcs_m
use, intrinsic :: iso_fortran_env, only: int64, real64
implicit none
private

    public :: simple_sum_tmpl, zero_int64, zero_real64
    public :: pairwise_sum_tmpl, average_tmpl

    requirement zeroing(T, zero)
        type, deferred :: T
        interface
            pure elemental function zero()
                implicit none
                type(T) :: zero
            end function
        end interface
    end requirement

    requirement adding(T, add)
        type, deferred :: T
        interface
            pure elemental function add(x, y)
                implicit none
                type(T), intent(in) :: x, y
                type(T) :: add
            end function
        end interface
    end requirement

    requirement dividing(T, divide)
        type, deferred :: T
        interface
            pure elemental function divide(x, y)
                implicit none
                type(T), intent(in) :: x, y
                type(T) :: divide
            end function
        end interface
    end requirement

    requirement vector_adding(T, add_vec)
        type, deferred :: T
        interface
            pure function add_vec(x)
                implicit none
                type(T), intent(in) :: x(:)
                type(T) :: add_vec
            end function
        end interface
    end requirement

    template simple_sum_tmpl(T, zero, add)
        requires zeroing(T, zero)
        requires adding(T, add)
        private
        public :: simple_sum
        contains
            pure function simple_sum(x) result(s)
                type(T), intent(in) :: x(:)
                type(T) :: s
                integer :: i
                s = zero()
                do i=1,size(x)
                    s = add(s, x(i))
                end do
            end function
    end template

    template pairwise_sum_tmpl(T, add_vec, add)
        requires vector_adding(T, add_vec)
        requires adding(T, add)
        private
        public :: pairwise_sum
        contains
            pure recursive function pairwise_sum(x) result(s)
                type(T), intent(in) :: x(:)
                type(T) :: s
                integer :: m
                if (size(x) <= 2) then
                    s = add_vec(x)
                else
                    m = size(x)/2
                    s = add(pairwise_sum(x(:m)), pairwise_sum(x(m+1:)))
                end if
            end function
    end template
    
    template average_tmpl(T, add_vec, divide)
        requires vector_adding(T, add_vec)
        requires dividing(T, divide)
        private
        public :: average
        contains
            pure function average(x)
                type(T), intent(in) :: x(:)
                type(T) :: average
                average = divide(add_vec(x), size(x))
            end function
    end template

    contains

        pure elemental function zero_int64()
            integer(int64) :: zero_int64
            zero_int64 = 0_int64
        end function

        pure elemental function zero_real64()
            real(real64) :: zero_real64
            zero_real64 = 0.0_real64
        end function

end module funcs_m

program main
use, intrinsic :: iso_fortran_env, only: int64, real64, output_unit, input_unit
use, non_intrinsic :: funcs_m
implicit none

    integer(int64) :: xi(5) = [1_int64, 2_int64, 3_int64, 4_int64, 5_int64], key, avi
    real(real64) :: xf(5) = [1.0_real64, 2.0_real64, 3.0_rea64, 4.0_real64, 5.0_real64], avf

    instantiate simple_sum_tmpl(integer(int64), zero_int64, operator(+)), only: simple_sum_int64 => simple_sum
    instantiate simple_sum_tmpl(real(real64), zero_real64, operator(+)), only: simple_sum_real64 => simple_sum
    instantiate pairwise_sum_tmpl(integer(int64), simple_sum_int64, operator(+)), only: pairwise_sum_int64 => pairwise_sum
    instantiate pairwise_sum_tmpl(real(real64), simple_sum_real64, operator(+)), only: pairwise_sum_real64 => pairwise_sum
    instantiate average_tmpl(integer(int64), simple_sum_int64, operator(/)), only: average_simple_sum_int64 => average
    instantiate average_tmpl(real(real64), simple_sum_real64, operator(/)), only: average_simple_sum_real64 => average
    instantiate average_tmpl(integer(int64), pairwise_sum_int64, operator(/)), only: average_pairwise_sum_int64 => average
    instantiate average_tmpl(real(real64), pairwise_sum_real64, operator(/)), only: average_pairwise_sum_real64 => average

    write(output_unit,'(a)') 'simple_sum average: 1'
    write(output_unit,'(a)') 'pairwise_sum average: 2'
    write(output_unit,'(a)', advance='no') 'choose an averaging method: '
    read(input_unit,'(i1)') key

    select case (key)
        case (1_int64)
            avi = average_simple_sum_int64(xi)
            avf = average_simple_sum_real64(xf)
        case (2_int64)
            avi = average_pairwise_sum_int64(xi)
            avf = average_pairwise_sum_real64(xf)
        case default
            error stop 'case not implemented'
    end select

    write(output_unit,'(i0)') avi
    write(output_unit,'(f0.1)') avf

end program main
