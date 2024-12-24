module extends

   abstract interface :: IParent
      subroutine method1(n)
         integer, intent(in) :: n
      end subroutine method1
   end interface IParent

   abstract interface :: IChild
      subroutine method2(res)
         real, intent(out) :: res
      end subroutine method2
   end interface IChild
   
   type, implements(IParent) :: Parent
   contains
      procedure, pass :: method1
   end type Parent

   type, extends(Parent), implements(IParent,IChild) :: Child
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

end module extends
