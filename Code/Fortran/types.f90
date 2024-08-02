module my_type

   use interfaces, only: IAdmissible, IPrintable

   implicit none
  
   type, sealed :: MyType
      private
      integer :: n
   end type MyType

  implements (IAdmissible,IPrintable) :: MyType
     procedure :: add, cast, output
  end implements MyType

contains

  function add(self,other) result(res)
     type(MyType), intent(in) :: self, other
     type(MyType)             :: res
     res%n = self%n + other%n
  end function add

  function cast(self,i) result(res)
     type(MyType), intent(in) :: self
     integer,      intent(in) :: i
     type(MyType)             :: res
     res%n = i
  end function cast

  subroutine output(self)
     type(MyType), intent(in) :: self
     write(*,'(a,i8)') "I am: ", self%n
  end subroutine output

end module my_type

module real_type

   use interfaces, only: IAdmissible, IPrintable

   implicit none
   
   implements (IAdmissible,IPrintable) :: real
      procedure :: add, cast, output
   end implements real

contains

  function add(self,other) result(res)
     real, intent(in) :: self, other
     real             :: res
     res = self + other
  end function add

  function cast(self,i) result(res)
     real,    intent(in) :: self
     integer, intent(in) :: i
     real                :: res
     res = real(i)
  end function cast

  subroutine output(self)
     real, intent(in) :: self
     write(*,'(a,f8.5)') "I am: ", self
  end subroutine output

end module real_type

program test

   use interfaces, only: IAdmissible, IPrintable
   use my_type
   use real_type

   implicit none

   integer      :: i
   real         :: arr_r(10)    ! array  of real type
   real         :: res_r        ! result of real type
   type(MyType) :: arr_t(10)    ! array  of MyType 
   type(MyType) :: res_t        ! result of MyType 

   ! initializations
   arr_r = [(real(i),i=1,10)]
   arr_t = [(MyType(i),i=1,10)] ! use of enhanced structure constructor

   ! use generic_sum with arrays of both types; no manual instantiations needed!
   res_r = generic_sum(arr_r)
   res_t = generic_sum(arr_t)
   
   ! print the results
   call printout(res_r,res_t)

contains

   pure function generic_sum{IAdmissible :: T}(arr) result(res)
      type(T), intent(in) :: arr(:)
      type(T)             :: res
      integer :: n, i
      n = size(arr)
      res = res%cast(0)
      if (n > 0) then
         res = arr(1)
         do i = 2, n
            res = res + arr(i)
         end do
      end if
   end function generic_sum

   subroutine printout{IPrintable :: T,U}(res1,res2)
      type(T), intent(in) :: res1
      type(U), intent(in) :: res2
      call res1%output()
      call res2%output()
   end subroutine printout
   
end program test
