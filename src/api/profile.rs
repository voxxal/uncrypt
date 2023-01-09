use axum::{
    extract::{Path, State},
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
    models::User,
    schema::users,
    AppState,
};

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProfileResponse {
    id: String,
    username: String,
    solved: i32,
    level: i32,
    experience: i32,
    exp_required: i32,
    exp_through: i32,
}

impl From<User> for ProfileResponse {
    fn from(user: User) -> Self {
        let exp_through = user.experience % 1000;
        let level = 1 + user.experience / 1000;
        let exp_required = 1000;
        Self {
            id: user.id,
            username: user.username,
            solved: user.solved,
            level,
            experience: user.experience,
            exp_required,
            exp_through,
        }
    }
}

async fn me(State(state): State<AppState>, auth: Auth) -> AppResult<Json<ProfileResponse>> {
    let conn = &mut state.db_pool.get().await?;

    if let Some(user) = users::table
        .filter(users::id.eq(auth.0.uid))
        .first::<User>(conn)
        .await
        .optional()?
    {
        return Ok(Json(ProfileResponse::from(user)));
    }

    return Err(AppError::from(StatusCode::UNAUTHORIZED, "Token invalid"));
}

async fn profile(
    State(state): State<AppState>,
    Path(username): Path<String>,
) -> AppResult<Json<ProfileResponse>> {
    let conn = &mut state.db_pool.get().await?;

    if let Some(user) = users::table
        .filter(users::username.eq(username))
        .first::<User>(conn)
        .await
        .optional()?
    {
        return Ok(Json(ProfileResponse::from(user)));
    }
    return Err(AppError::from(StatusCode::NOT_FOUND, "Profile not found"));
}

pub fn app() -> Router<AppState> {
    Router::new()
        .route("/", get(me))
        .route("/:username", get(profile))
}
