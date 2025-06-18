pub mod vector_library {
    pub trait IAppendable {
        type Element;
        fn append(&mut self, item: Self::Element);
    }

    pub struct Vector<U> {
        elements: Vec<U>,
    }

    impl<U> Vector<U> {
        pub fn new(item: U) -> Vector<U>{
            let mut elements = Vec::new();
            elements.push(item);
            Vector{
                elements: elements,
            }
        }
    }
    
    impl<U: std::fmt::Debug> Vector<U> {
        pub fn printout(&self) {
            println!("{:?}",self.elements);
        }
    }
    
    impl<U> IAppendable for Vector<U> {
        type Element = U;
        fn append(&mut self, item: U) {
            self.elements.push(item);
        }
    }
}

fn main() {
    use crate::vector_library::{IAppendable,Vector};
    
    let mut doubles = Vector::new(&0.0f64);
    doubles.append(&1.5f64);
    doubles.append(&2.2f64);
    doubles.printout();

    let mut bools = Vector::new(&true);
    bools.append(&false);
    bools.append(&true);
    bools.printout();

    let mut strings = Vector::new(&"John");
    strings.append(&"Mary");
    strings.append(&"Anne");
    strings.printout();
}
