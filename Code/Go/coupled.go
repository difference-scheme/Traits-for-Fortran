package main

import "fmt"

func simple_sum(x []int32) int32 {
   var s int32
   s = 0
   for i := 0; i < len(x); i++ {
     s += x[i]
   }
   return s
}

func pairwise_sum(x []int32) int32 {
   if len(x) <= 2 {
      return simple_sum(x)
   } else {
      m := len(x) / 2
      return pairwise_sum(x[:m+1]) + pairwise_sum(x[m+1:])
   }
}

func simple_average(x []int32) int32 {
   return simple_sum(x) / int32(len(x))
}

func pairwise_average(x []int32) int32 {
   return pairwise_sum(x) / int32(len(x))
}

// ..............
// main program
// ..............

func main() {

   xi := []int32{1,2,3,4,5}

   var key int32

   fmt.Println("Simple   sum average: 1")
   fmt.Println("Pairwise sum average: 2")
   fmt.Print("Choose an averaging method: ")
   fmt.Scan(&key)

   switch key {
   case 1:
      fmt.Println(simple_average(xi))
   case 2:
      fmt.Println(pairwise_average(xi))
   default:
      fmt.Println("Case not implemented!")
   }

}