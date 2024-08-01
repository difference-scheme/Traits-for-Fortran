module vector_library

   implicit none
   private

   abstract interface :: IAnyType
   end interface IAnyType
   
   abstract interface :: IAppendable
      subroutine append(self,item)
         deferred(self), intent(inout) :: self
         deferred(item), intent(in)    :: item
      end subroutine append
   end interface IAppendable

   type, public, implements(IAppendable) :: Vector{IAnyType :: U}
      private
      type(U), allocatable :: elements(:)
   contains
      procedure :: append
   end type Vector

contains

   subroutine append(self,item)
      class(Vector{U}), intent(inout) :: self
      type(U),          intent(in)    :: item
      self%elements = [self%elements,item]
   end subroutine append

end module vector_library
