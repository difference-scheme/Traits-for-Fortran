package main

import "fmt"

type IAppendable[U any] interface {
	append(item U)
	printout()
}

type Vector[U any] struct {
	elements []U
}

func (self *Vector[U]) append(item U) {
	// use the built-in append function for arrays
        self.elements = append(self.elements, item)
}

func (self *Vector[U]) printout() {
        fmt.Println(self.elements)
}

func main() {
	
	var doubles IAppendable[float64]
	var bools   IAppendable[bool]
	var strings IAppendable[string]
	
	doubles = &Vector[float64]{[]float64{0.0}}
	doubles.append(float64(1.5))
	doubles.append(float64(2.2))
	doubles.printout()
    
	bools = &Vector[bool]{[]bool{true}}
	bools.append(false)
	bools.append(true)
	bools.printout()
	
	strings = &Vector[string]{[]string{"John"}}
	strings.append("Mary")
	strings.append("Anne")
	strings.printout()
}
