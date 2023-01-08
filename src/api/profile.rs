use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::get,
    Json, Router,
};
use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use serde::{Serialize};

use crate::{
    auth::Auth,
    error::{AppError, AppResult},
    models::User,
    schema::users,
    AppState,
};

#[derive(Serialize)]
struct ProfileResponse {
    username: String,
}

async fn profile(
    State(state): State<AppState>,
    Path(username): Path<String>,
    auth: Option<Auth>,
) -> AppResult<Json<ProfileResponse>> {
    let conn = &mut state.db_pool.get().await?;
    if username.is_empty() {
        if let Some(auth) = auth {
            if let Some(user) = users::table
                .filter(users::id.eq(auth.0.uid))
                .first::<User>(conn)
                .await
                .optional()?
            {
                return Ok(Json(ProfileResponse {
                    username: user.username,
                }));
            }

            return Err(AppError::from(StatusCode::UNAUTHORIZED, "Token invalid"));
        }
        return Err(AppError::from(StatusCode::UNAUTHORIZED, "Token not found"));
    } else {
        if let Some(user) = users::table
            .filter(users::username.eq(username))
            .first::<User>(conn)
            .await
            .optional()?
        {
            return Ok(Json(ProfileResponse {
                username: user.username,
            }));
        }
        return Err(AppError::from(StatusCode::NOT_FOUND, "Profile not found"));

    }
}

pub fn app() -> Router<AppState> {
    Router::new().route("/:username", get(profile))
}
