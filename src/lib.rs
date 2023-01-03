#![feature(array_zip)]
pub mod api;
pub mod client;
pub mod error;
pub mod models;
pub mod schema;

use axum::{routing::get, Router};
use deadpool::managed::Pool;
use diesel_async::{pooled_connection::AsyncDieselConnectionManager, AsyncPgConnection};

pub type DbConnection = AsyncDieselConnectionManager<AsyncPgConnection>;
pub type DbPool = Pool<DbConnection>;

pub fn establish_connection(db_url: &str) -> DbPool {
    let db_config = DbConnection::new(db_url);
    Pool::builder(db_config)
        .build()
        .expect("failed to build database pool")
}

pub fn app() -> Router {
    Router::new()
        .nest_service("/", get(client::file_handler))
        .nest("/api", api::app())
}