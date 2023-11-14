package main

import "fmt"

type INumeric interface{ int32 | float64 }

func simple_sum[T INumeric](x []T) T {
   var s T
   s = T(0)
   for i := 0; i < len(x); i++ {
     s += x[i]
   }
   return s
}

func pairwise_sum[T INumeric](x []T) T {
   if len(x) <= 2 {
      return simple_sum(x)
   }
   m := len(x) / 2
   return pairwise_sum(x[:m+1]) + pairwise_sum(x[m+1:])
}

func average[T INumeric](sum func([]T) T, x []T) T {
   return sum(x) / T(len(x))
}

func main() {
   xi := []int32{1, 2, 3, 4, 5}
   xf := []float64{1, 2, 3, 4, 5}

   var key int32
   var avi func([]int32) int32
   var avf func([]float64) float64

   fmt.Println("Simple   sum average:", 1)
   fmt.Println("Pairwise sum average:", 2)
   fmt.Print("Choose an averaging method: ")
   fmt.Scan(&key)

   switch key {
      case 1:
	 avi = func(x []int32) int32 {
                  return average(simple_sum[int32], x)
               }
         avf = func(x []float64) float64 {
                  return average(simple_sum[float64], x)
               }
      case 2:
	 avi = func(x []int32) int32 {
                  return average(pairwise_sum[int32], x)
               }
	 avf = func(x []float64) float64 {
                  return average(pairwise_sum[float64], x)
               }
      default:
	 fmt.Println("Case not implemented!")
	 return
    }

    fmt.Println(avi(xi))
    fmt.Println(avf(xf))
}
