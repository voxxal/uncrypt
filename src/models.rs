use diesel::prelude::*;

#[derive(Queryable)]
pub struct Message {
    pub id: i32,
    pub message: String,
    pub patristocrat_hint: Option<String>,
    pub published: Option<String>,
}