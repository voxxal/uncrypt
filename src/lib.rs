#![feature(array_zip)]
#![feature(let_else)]
pub mod api;
pub mod auth;
pub mod error;
pub mod exp;
pub mod models;
pub mod schema;
pub mod util;

use axum::Router;
use axum_extra::routing::SpaRouter;
use deadpool::managed::Pool;
use diesel_async::{pooled_connection::AsyncDieselConnectionManager, AsyncPgConnection};
use ring::hmac;

pub type DbConnection = AsyncDieselConnectionManager<AsyncPgConnection>;
pub type DbPool = Pool<DbConnection>;

#[derive(Clone)]
pub struct AppState {
    pub db_pool: DbPool,
    pub hmac_key: hmac::Key,
}

pub fn establish_connection(db_url: &str) -> DbPool {
    let db_config = DbConnection::new(db_url);
    Pool::builder(db_config)
        .build()
        .expect("failed to build database pool")
}

pub fn app() -> Router<AppState> {
    Router::new()
        .nest("/api", api::app())
        .merge(SpaRouter::new("/assets", "client/dist/assets").index_file("../index.html"))
}
