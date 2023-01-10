use std::time::Duration;

use axum::{extract::State, http::StatusCode, routing::post, Json, Router};
use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use nanoid::nanoid;
use serde::{Deserialize, Serialize};

use crate::{
    auth,
    error::{AppError, AppResult},
    models::User,
    schema::users,
    AppState,
};

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct UserAuthorizedResponse {
    token: String,
}

impl UserAuthorizedResponse {
    fn from_user(user: &User) -> anyhow::Result<Self> {
        Ok(Self {
            token: auth::generate_jwt(user, Duration::from_secs(24 * 60 * 60))?,
        })
    }
}

#[derive(Deserialize)]
struct RegisterRequest {
    pub username: String,
    pub password: String,
    pub email: Option<String>
}

async fn register(
    State(state): State<AppState>,
    Json(req): Json<RegisterRequest>,
) -> AppResult<Json<UserAuthorizedResponse>> {
    #[derive(Insertable)]
    #[diesel(table_name = users)]
    struct NewUser {
        id: String,
        username: String,
        password_hash: String,
        solved: i32,
    }

    if req.username.len() > 32 {
        return Err(AppError::from(StatusCode::BAD_REQUEST, "username too long"));
    }

    let conn = &mut state.db_pool.get().await?;

    let new_user = diesel::insert_into(users::table)
        .values(NewUser {
            id: nanoid!(),
            username: req.username,
            password_hash: auth::hash_password(req.password).unwrap(),
            solved: 0,
        })
        .on_conflict(users::username)
        .do_nothing()
        .get_result::<User>(conn)
        .await
        .optional()?;

    let Some(new_user) = new_user else {
            return Err(AppError::from(
                StatusCode::CONFLICT,
                "username has been taken",
            ));
        };

    Ok(Json(UserAuthorizedResponse::from_user(&new_user)?))
}

#[derive(Deserialize)]
struct LoginRequest {
    pub username: String,
    pub password: String,
}

async fn login(
    State(state): State<AppState>,
    Json(req): Json<LoginRequest>,
) -> AppResult<Json<UserAuthorizedResponse>> {
    let conn = &mut state.db_pool.get().await?;

    if let Some(user) = users::table
        .filter(users::username.eq(req.username))
        .first::<User>(conn)
        .await
        .optional()?
    {
        if auth::verify_password(req.password, &user.password_hash).unwrap() {
            return Ok(Json(UserAuthorizedResponse::from_user(&user)?));
        }
    }

    Err(AppError::from(
        StatusCode::UNAUTHORIZED,
        "invalid username or password",
    ))
}

pub fn app() -> Router<AppState> {
    Router::new()
        .route("/register", post(register))
        .route("/login", post(login))
}
