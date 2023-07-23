package main

import ("fmt")

func simple_sum(x []int) int {
   var s int
   s = 0
   for i := 0; i < len(x); i++ {
     s += x[i]
   }
   return s
}

func pairwise_sum(x []int) int {
   N := 2
   if ( len(x) <= N ) {
     return simple_sum(x)
   } else {
     m := len(x) / 2
     return pairwise_sum(x[:m+1]) + pairwise_sum(x[m+1:])
   }
}

func simple_average(x []int) int {
   return simple_sum(x) / len(x)
}

func pairwise_average(x []int) int {
   return pairwise_sum(x) / len(x)
}

// ..............
// main program
// ..............

func main() {

   xi := []int{1,2,3,4,5}

   var key int

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