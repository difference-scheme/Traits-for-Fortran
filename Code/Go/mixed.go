package main

import "fmt"

// ...........
// Interfaces
// ...........

type INumeric interface {
   int32 | float64
}

type ISum[T INumeric] interface {
   sum(x []T) T
}

type IAverager[T INumeric] interface {
   average(x []T) T
}

// ..............
// SimpleSum ADT
// ..............

type SimpleSum[T INumeric] struct {
}

func (self SimpleSum[T]) sum(x []T) T {
   var s T
   s = T(0)
   for i := 0; i < len(x); i++ {
     s += x[i]
   }
   return s
}

// ................
// PairwiseSum ADT
// ................

type PairwiseSum[T INumeric] struct {
   other ISum[T]
}

func (self PairwiseSum[T]) sum(x []T) T {
   if len(x) <= 2 {
      return self.other.sum(x)
   } else {
      m := len(x) / 2
      return self.sum(x[:m+1]) + self.sum(x[m+1:])
   }
}

// .............
// Averager ADT
// .............

type Averager[T INumeric] struct {
   drv ISum[T]
}

func (self Averager[T]) average(x []T) T {
   return self.drv.sum(x) / T(len(x))
}

// ..............
// main program
// ..............

func main() {

   var avi IAverager[int32]
   var avf IAverager[float64]

   xi := []int32{1,2,3,4,5}
   xf := []float64{1.,2.,3.,4.,5.}

   var key int32

   fmt.Println("Simple   sum average: 1")
   fmt.Println("Pairwise sum average: 2")
   fmt.Print("Choose an averaging method: ")
   fmt.Scan(&key)

   switch key {
   case 1:
      avi = Averager[int32]{ SimpleSum[int32]{} }
      avf = Averager[float64]{ SimpleSum[float64]{} }
   case 2:
      avi = Averager[int32]{ PairwiseSum[int32]{ SimpleSum[int32]{} } }
      avf = Averager[float64]{ PairwiseSum[float64]{ SimpleSum[float64]{} } }
   default:
      fmt.Println("Case not implemented!")
   }

   fmt.Println(avi.average(xi))
   fmt.Println(avf.average(xf))
}