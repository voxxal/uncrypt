use diesel::prelude::*;

#[derive(Queryable)]
pub struct Message {
    pub id: i32,
    pub message: String,
    pub patristocrat_hint: Option<String>,
    pub published: Option<String>,
}

#[derive(Queryable)]
pub struct User {
    pub id: String,
    pub username: String,
    pub email: Option<String>,
    pub password_hash: String,
    pub solved: i32,
}