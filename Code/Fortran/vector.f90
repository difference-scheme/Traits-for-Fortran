module vector_library

   use, intrinsic :: generic_constraints, only: IAnyType
   
   implicit none
   private

   abstract interface :: IAppendable
      ! associated type "Element"
      type, alias :: Element

      subroutine append(self, item)
         import; implicit none
         class(IAppendable), intent(inout) :: self
         type(Element),      intent(in)    :: item
      end subroutine append
   end interface

   type, public, implements(IAppendable) :: Vector{IAnyType :: U}
      private
      type(U), allocatable :: elements(:)
   contains
      procedure :: append
   end type Vector

contains

   subroutine append(self, item)
      class(Vector{U}), intent(inout) :: self
      type(U),          intent(in)    :: item
      self%elements = [self%elements, item]
   end subroutine append

end module vector_library
