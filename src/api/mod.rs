use axum::Router;

pub mod message;

pub fn app() -> Router {
    Router::new()
        .nest("/aristocrat", message::app())
}
