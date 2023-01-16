use std::collections::HashMap;

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    routing::get,
    Json, Router,
};
use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use serde::Serialize;

use crate::{
    auth::Auth,
    error::{AppError, AppResult},
    models::{Message, Solve, User},
    schema::{messages, solves, users},
    AppState,
};

use super::PuzzleType;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SolveResponse {
    pub puzzle_type: PuzzleType,
    pub plaintext: String,
    pub attribution: String,
    pub solved_at: String,
    pub solver: String,
    pub time_taken: i32,
    pub exp_gained: i32,
}

impl SolveResponse {
    fn new(user: &User, solve: &Solve, message: &Message) -> AppResult<Self> {
        Ok(Self {
            puzzle_type: PuzzleType::try_from(solve.puzzle_type)?,
            plaintext: message.message.clone(),
            attribution: message
                .attribution
                .clone()
                .unwrap_or(String::from("Unknown")),
            solved_at: format!("{}", solve.solved_at.format("%F %I:%M %P")),
            solver: user.username.clone(),
            time_taken: solve.time_taken,
            exp_gained: solve.exp_gained,
        })
    }
}

async fn me(
    State(state): State<AppState>,
    Query(params): Query<HashMap<String, String>>,
    auth: Auth,
) -> AppResult<Json<Vec<SolveResponse>>> {
    let conn = &mut state.db_pool.get().await?;

    if let Some(user) = users::table
        .filter(users::id.eq(auth.0.uid))
        .first::<User>(conn)
        .await
        .optional()?
    {
        let solves = Solve::belonging_to(&user)
            .limit(
                params
                    .get("limit")
                    .map(|x| x.parse().ok())
                    .flatten()
                    .unwrap_or(10),
            )
            .order(solves::id.desc())
            .load::<Solve>(conn)
            .await?;

        let mut solve_responses = vec![];
        for solve in solves {
            let message = messages::table
                .filter(messages::id.eq(solve.message_id))
                .first::<Message>(conn)
                .await?;
            solve_responses.push(SolveResponse::new(&user, &solve, &message)?)
        }
        return Ok(Json(solve_responses));
    }

    return Err(AppError::from(StatusCode::UNAUTHORIZED, "Token invalid"));
}

async fn solves(
    State(state): State<AppState>,
    Query(params): Query<HashMap<String, String>>,
    Path(username): Path<String>,
) -> AppResult<Json<Vec<SolveResponse>>> {
    let conn = &mut state.db_pool.get().await?;

    if let Some(user) = users::table
        .filter(users::username.eq(username))
        .first::<User>(conn)
        .await
        .optional()?
    {
        let solves = Solve::belonging_to(&user)
            .limit(
                params
                    .get("limit")
                    .map(|x| x.parse().ok())
                    .flatten()
                    .unwrap_or(10),
            )
            .order(solves::id.desc())
            .load::<Solve>(conn)
            .await?;

        let mut solve_responses = vec![];
        for solve in solves {
            let message = messages::table
                .filter(messages::id.eq(solve.message_id))
                .first::<Message>(conn)
                .await?;
            solve_responses.push(SolveResponse::new(&user, &solve, &message)?)
        }
        return Ok(Json(solve_responses));
    }
    return Err(AppError::from(StatusCode::NOT_FOUND, "Profile not found"));
}

pub fn app() -> Router<AppState> {
    Router::new()
        .route("/", get(me))
        .route("/:username", get(solves))
}
