use serde::Serialize;

#[derive(Serialize)]
pub struct ExpSource {
    pub name: String,
    pub amount: String,
    pub special: bool,
}

impl ExpSource {
    pub fn additive<T: ToString>(name: T, amount: i32) -> Self {
        Self {
            name: name.to_string(),
            amount: format!("+{amount}"),
            special: false
        }
    }
}

pub fn exp_to_level(exp: i32) -> i32 {
    1 + exp / 1000
}

pub fn exp_through(exp: i32) -> i32 {
    exp % 1000
}
