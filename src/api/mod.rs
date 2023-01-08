use axum::Router;

use crate::AppState;

pub mod aristocrat;
pub mod auth;
pub mod profile;

pub fn app() -> Router<AppState> {
    Router::new()
        .nest("/aristocrat", aristocrat::app())
        .nest("/profile", profile::app())
        .nest("/auth", auth::app())
}
