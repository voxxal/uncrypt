use axum::Router;
use diesel::Insertable;
use serde::Serialize;

use crate::{exp::ExpSource, models::User, schema::solves, AppState};

use self::profile::ProfileResponse;

pub mod aristocrat;
pub mod auth;
pub mod baconian;
pub mod profile;

pub fn app() -> Router<AppState> {
    Router::new()
        .nest("/aristocrat", aristocrat::app())
        .nest("/baconian", baconian::app())
        .nest("/profile", profile::app())
        .nest("/auth", auth::app())
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SubmitResponse {
    plaintext: String,
    time_taken: u128,
    profile: Option<ProfileResponse>,
    exp_sources: Option<Vec<ExpSource>>,
    total_exp: Option<i32>,
}

pub enum PuzzleType {
    Aristocrat = 0,
    Baconian = 1,
}

#[derive(Insertable)]
#[diesel(table_name = solves)]
pub struct NewSolve {
    puzzle_type: i16,
    message_id: i32,
    solver: String,
    time_taken: i32,
    exp_gained: i32,
}

impl NewSolve {
    pub fn new(
        puzzle_type: PuzzleType,
        message_id: i32,
        solver: &User,
        time_taken: i32,
        exp_gained: i32,
    ) -> Self {
        Self {
            puzzle_type: puzzle_type as i16,
            message_id,
            solver: solver.id.clone(),
            time_taken,
            exp_gained,
        }
    }
}
