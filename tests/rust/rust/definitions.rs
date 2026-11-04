/// Returns its input.
#[inline]
pub fn plain(a: u8) -> u8 {
    fn inner() {}
    a
}

pub struct Unit;
pub struct Tuple(u8);
pub struct Named<T> {
    field: T,
}

enum Choice {
    A,
    B(u8),
}

union Bits {
    a: u32,
    b: f32,
}

trait Shape {
    fn area(&self) -> f64;
    fn name(&self) -> &str {
        "shape"
    }
}

impl Shape for Unit {
    fn area(&self) -> f64 {
        0.0
    }
}

impl<T> Named<T> {
    fn new(field: T) -> Self {
        Self { field }
    }
}

impl std::fmt::Debug for crate::Tuple {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        Ok(())
    }
}

impl Shape for &Unit {
    fn area(&self) -> f64 {
        1.0
    }
}

mod outer {
    pub mod inner {}
}

mod declared;

const LIMIT: u8 = 1;
static NAME: &str = "rust";
type Alias = u8;

macro_rules! twice {
    ($e:expr) => {
        $e + $e
    };
}

extern "C" {
    fn external(x: i32) -> i32;
}

let_not_an_item!();
