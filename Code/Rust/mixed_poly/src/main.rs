pub mod interfaces {

    use num::Num;
    use std::ops::AddAssign;

    // ...........
    // Interfaces
    // ...........

    pub trait INumeric: Num + AddAssign {
        fn new(n: usize) -> Self;
    }

    pub trait ISum<T> {
        fn sum(&self, x: &[T]) -> T;
    }

    pub trait IAverager<T> {
        fn average(&self, x: &[T]) -> T;
    }
}

pub mod intrinsics {

    use crate::interfaces::INumeric;
    
    impl INumeric for i32 {
        fn new(n: usize) -> i32 {
            return n as i32
        }
    }
    
    impl INumeric for f64 {
        fn new(n: usize) -> f64 {
            return n as f64
        }
    }

}

pub mod simple_library {

    use crate::interfaces::{INumeric,ISum};

    // ..............
    // SimpleSum ADT
    // ..............

    pub struct SimpleSum;
    
    impl<T> ISum<T> for SimpleSum where T: INumeric + Copy {
        fn sum(&self, x: &[T]) -> T {
            let mut s: T;
            s = T::new(0);
            for i in 0 .. x.len() {
                s += x[i];
            }
            return s
        }
    }

}

pub mod pairwise_library {

    use crate::interfaces::{INumeric,ISum};
    
    // ................
    // PairwiseSum ADT
    // ................

    pub struct PairwiseSum<T> {
        other: Box<dyn ISum<T>>,
    }

    impl<T> PairwiseSum<T> where T: INumeric {
        pub fn new(other: Box<dyn ISum<T>>) -> PairwiseSum<T> {
            PairwiseSum{
                other: other,
            }
        }
    }
    
    impl<T> ISum<T> for PairwiseSum<T> where T: INumeric {
        fn sum(&self, x: &[T]) -> T {
            if  x.len() <= 2 {
                return self.other.sum(x);
            } else {
                let m = x.len() / 2;
                return self.sum(&x[..m+1]) + self.sum(&x[m+1..]);
            }
        }
    }

}

pub mod averager_library {

    use crate::interfaces::{INumeric,ISum,IAverager};
    
    // .............
    // Averager ADT
    // .............
    
    pub struct Averager<T> {
        drv: Box<dyn ISum<T>>,
    }
    
    impl<T> Averager<T> where T: INumeric {
        pub fn new(drv: Box<dyn ISum<T>>) -> Averager<T> {
            Averager{
                drv: drv,
            }
        }
    }
    
    impl<T> IAverager<T> for Averager<T> where T: INumeric {
        fn average(&self, x: &[T]) -> T {
            return self.drv.sum(&x) / T::new(x.len());
        }
    }

}
// ..............
// main program
// ..............
#[macro_use] extern crate text_io;

fn main() {
    use crate::interfaces::IAverager;
    use crate::simple_library::SimpleSum;
    use crate::pairwise_library::PairwiseSum;
    use crate::averager_library::Averager;

    let avsi = Averager::new(Box::new(SimpleSum{}));
    let avsf = Averager::new(Box::new(SimpleSum{}));

    let avpi = Averager::new(Box::new(PairwiseSum::new(Box::new(SimpleSum{}))));
    let avpf = Averager::new(Box::new(PairwiseSum::new(Box::new(SimpleSum{}))));

    let mut avi: Box<dyn IAverager::<i32>> = Box::new(avsi);
    let mut avf: Box<dyn IAverager::<f64>> = Box::new(avsf);

    let xi : [i32;5] = [1,2,3,4,5];
    let xf : [f64;5] = [1.,2.,3.,4.,5.];

    let key: i32;

    println!("Simple   sum average: 1");
    println!("Pairwise sum average: 2");
    scan!("{}\n",key);

    match key {
        1 => {}
        2 => { avi = Box::new(avpi);
               avf = Box::new(avpf); }
        _ => { println!("Case not implemented!");
               return; }
    }

    println!("{}", avi.average(&xi));
    println!("{}", avf.average(&xf));
}
