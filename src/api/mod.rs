use axum::Router;

pub mod message;

pub fn app() -> Router {
    Router::new()
        .nest("/msg", message::app())
}
