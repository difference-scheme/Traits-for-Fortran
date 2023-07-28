package main

import "fmt"

type INumeric interface{ int | float64 }

func simple_sum[T INumeric](x []T) T {
   var s T
   s = T(0)
   for i := 0; i < len(x); i++ {
     s += x[i]
   }
   return s
}

func pairwise_sum[T INumeric](sum func([]T) T, x []T) T {
   if len(x) <= 2 {
      return sum(x)
   }
   m := len(x) / 2
   return pairwise_sum(sum,x[:m+1]) + pairwise_sum(sum,x[m+1:])
}

func average[T INumeric](sum func([]T) T, x []T) T {
   return sum(x) / T(len(x))
}

func main() {
   xi := []int{1, 2, 3, 4, 5}
   xf := []float64{1, 2, 3, 4, 5}

   var key int
   var avi, psi func([]int) int
   var avf, psf func([]float64) float64

   fmt.Println("Simple   sum average:", 1)
   fmt.Println("Pairwise sum average:", 2)
   fmt.Print("Choose an averaging method: ")
   fmt.Scan(&key)

   switch key {
      case 1:
	 avi = func(x []int) int {
                  return average(simple_sum[int], x)
               }
         avf = func(x []float64) float64 {
                  return average(simple_sum[float64], x)
               }
      case 2:
         psi = func(x []int) int {
                  return pairwise_sum(simple_sum[int], x)
               }

         psf = func(x []float64) float64 {
                  return pairwise_sum(simple_sum[float64], x)
               }

	 avi = func(x []int) int {
                  return average(psi, x)
               }

	 avf = func(x []float64) float64 {
                  return average(psf, x)
               }
      default:
	 fmt.Println("Case not implemented!")
	 return
    }

    fmt.Println(avi(xi))
    fmt.Println(avf(xf))
}
