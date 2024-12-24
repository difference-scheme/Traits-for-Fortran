module basic_interfaces

   implicit none
   private

   public :: IReducible, IPrintable

   abstract interface :: IReducible
      function init(n)
         integer, intent(in) :: n
      end function init
      elemental function operator(*)(lhs,rhs) result(res)
         type(itself), intent(in) :: lhs, rhs
         type(itself)             :: res
      end function operator(*)
      elemental function operator(*)(lhs,rhs) result(res)
         type(itself), intent(in) :: lhs
         integer,      intent(in) :: rhs
         type(itself)             :: res
      end function operator(*)
   end interface IReducible
   
   abstract interface :: IPrintable
      subroutine output()
      end subroutine output
   end interface IPrintable

end module basic_interfaces

module my_type

   use basic_interfaces, only: IReducible, IPrintable

   implicit none
   private
   
   type, public, sealed :: MyType
      private
      integer :: n
   end type MyType

   implements (IReducible,IPrintable) :: MyType
      initial :: init
      procedure, nopass :: operator(*) => multiply, multiply_by_int
      procedure, pass   :: output
   end implements MyType

contains
   
   function init(n) result(self)
      integer, intent(in) :: n
      type(MyType)        :: self
      self%n = n
   end function init
   
   elemental function multiply(lhs,rhs) result(res)
      type(MyType), intent(in) :: lhs, rhs
      type(MyType)             :: res
      res%n = lhs%n * rhs%n
   end function multiply

   elemental function multiply_by_int(lhs,rhs) result(res)
      type(MyType), intent(in) :: lhs
      integer,      intent(in) :: rhs
      type(MyType)             :: res
      res%n = lhs%n * rhs
   end function multiply_by_int
   
   subroutine output(self)
      type(MyType), intent(in) :: self
      write(*,'(a,i8)') "I am: ", self%n
   end subroutine output

end module my_type

module real_type

   use basic_interfaces, only: IReducible, IPrintable

   implicit none
   private
   
   implements (IReducible,IPrintable) :: real
      procedure, pass :: output
   end implements real

contains

   subroutine output(self)
      real, intent(in) :: self
      write(*,'(a,f8.5)') "I am: ", self
   end subroutine output

end module real_type

program main

   use basic_interfaces, only: IReducible, IPrintable
   use my_type,          only: MyType

   implicit none

   integer      :: i
   type(MyType) :: at(4)     ! Array of MyType 
   real         :: ar(4)     ! Array of real type
   
   ! initializations
   at = [(MyType(i),i=1,4)]  ! Use of user-defined initializer/constructor
   ar = [(real(i),i=1,4)]    ! Use of built-in initializer (i.e. cast)
   
   call products(at,ar)
   
contains

   subroutine products{IReducible,IPrintable :: T,R}(at,ar)
      type(T), intent(in) :: at(4)
      type(R), intent(in) :: ar(4)
      type(T) :: st                      ! Scalar of type(T)
      type(R) :: sr                      ! Scalar of type(R)
      st = prod( (at * at) * [4,3,2,1] ) ! Reduce arrays to scalars after
      sr = prod( (ar * ar) * [4,3,2,1] ) ! elementwise multiplication operations
      call st%output()                   ! Print the results
      call sr%output()                   ! (13824 in both cases)
   end subroutine products

   function prod{IReducible :: T}(arr) result(res)
      type(T), intent(in) :: arr(:)
      type(T)             :: res
      integer :: i
      res = T(1)                         ! Use initializer for cast
      do i = 1, size(arr)
         res = res * arr(i)              ! Use operator(*) for reduction
      end do
   end function prod
   
end program main
