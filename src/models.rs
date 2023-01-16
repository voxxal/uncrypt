use crate::schema::{messages, solves, users};
use diesel::prelude::*;

#[derive(Identifiable, Queryable, Debug)]
#[diesel(table_name = messages)]

pub struct Message {
    pub id: i32,
    pub message: String,
    pub patristocrat_hint: Option<String>,
    pub attribution: Option<String>,
}

#[derive(Identifiable, Queryable)]
#[diesel(table_name = users)]
pub struct User {
    pub id: String,
    pub username: String,
    pub email: Option<String>,
    pub password_hash: String,
    pub solved: i32,
    pub experience: i32,
}

#[derive(Identifiable, Queryable, Associations)]
#[diesel(belongs_to(User, foreign_key = solver), belongs_to(Message),  table_name = solves)]
pub struct Solve {
    pub id: i32,
    pub puzzle_type: i16,
    pub message_id: i32,
    pub solver: String,
    pub time_taken: i32,
    pub exp_gained: i32,
}
