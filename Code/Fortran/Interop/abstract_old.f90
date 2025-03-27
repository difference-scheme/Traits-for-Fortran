module abstract_old
   
   type, abstract :: Parent
   contains
      procedure, pass :: method1 => implementation1
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
      procedure, pass :: method2 => implementation2
   end type Child

contains

   subroutine implementation1(self,n)
      class(Parent), intent(in) :: self
      integer,       intent(in) :: n
   end subroutine implementation1
   
   subroutine implementation2(self,res)
      class(Child), intent(in)  :: self
      real,         intent(out) :: res
   end subroutine implementation2

end module abstract_old
