module abstract2a
   
   type, abstract :: Parent
   contains
      procedure, pass :: method1
      procedure(method2), deferred, pass :: method2
   end type Parent

   abstract interface
      subroutine method2(self,res)
         import
         class(Parent), intent(in)  :: self
         real,          intent(out) :: res
      end subroutine method2
   end interface
   
   type, extends(Parent) :: Child
   contains
      procedure, pass :: method2
   end type Child

contains

   subroutine method1(self,n)
      class(Parent), intent(in) :: self
      integer,       intent(in) :: n
   end subroutine method1
   
   subroutine method2(self,res)
      class(Child), intent(in)  :: self
      real,         intent(out) :: res
   end subroutine method1

end module abstract2a
