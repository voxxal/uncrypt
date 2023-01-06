use axum::Router;

use crate::AppState;

pub mod auth;
pub mod aristocrat;

pub fn app() -> Router<AppState> {
    Router::new()
        .nest("/aristocrat", aristocrat::app())
        .nest("/auth", auth::app())
}
