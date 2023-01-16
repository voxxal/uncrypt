use anyhow::anyhow;
use axum::Router;
use diesel::Insertable;
use serde::Serialize;

use crate::{error::AppError, exp::ExpSource, models::User, schema, AppState};
use std::convert::TryFrom;

use self::profile::ProfileResponse;

pub mod aristocrat;
pub mod auth;
pub mod baconian;
pub mod profile;
pub mod solves;

pub fn app() -> Router<AppState> {
    Router::new()
        .nest("/aristocrat", aristocrat::app())
        .nest("/baconian", baconian::app())
        .nest("/profile", profile::app())
        .nest("/solves", solves::app())
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

#[repr(i16)]
#[derive(Serialize)]
pub enum PuzzleType {
    Aristocrat = 0,
    Baconian = 1,
}

impl TryFrom<i16> for PuzzleType {
    type Error = AppError;

    fn try_from(v: i16) -> Result<Self, Self::Error> {
        match v {
            x if x == PuzzleType::Aristocrat as i16 => Ok(PuzzleType::Aristocrat),
            x if x == PuzzleType::Baconian as i16 => Ok(PuzzleType::Baconian),
            _ => Err(AppError::InternalServerError(anyhow!("invalid PuzzleType"))),
        }
    }
}

#[derive(Insertable)]
#[diesel(table_name = schema::solves)]
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
