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
            let mut s = T::new(0);
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
    use std::io;
    use std::io::Write;
    use crate::interfaces::IAverager;
    use crate::simple_library::SimpleSum;
    use crate::pairwise_library::PairwiseSum;
    use crate::averager_library::Averager;

    let avi: Box<dyn IAverager::<i32>>;
    let avf: Box<dyn IAverager::<f64>>;
    let key: i32;

    println!("Simple   sum average: 1");
    println!("Pairwise sum average: 2");
    print!("Choose an averaging method: ");

    io::stdout().flush().unwrap();
    scan!("{}\n",key);

    let ssi = SimpleSum{};
    let ssf = SimpleSum{};
    let psi = PairwiseSum::new(Box::new(SimpleSum{}));
    let psf = PairwiseSum::new(Box::new(SimpleSum{}));
    
    match key {
        1 => { avi = Box::new(Averager::new(Box::new(ssi))); 
               avf = Box::new(Averager::new(Box::new(ssf))); }
        2 => { avi = Box::new(Averager::new(Box::new(psi)));
               avf = Box::new(Averager::new(Box::new(psf))); }
        _ => { println!("Case not implemented!");
               return; }
    }

    let xi: [i32;5] = [1,2,3,4,5];
    let xf: [f64;5] = [1.,2.,3.,4.,5.];
    
    println!("{}", avi.average(&xi));
    println!("{:.1}", avf.average(&xf));
}
