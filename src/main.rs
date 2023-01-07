use std::env;

use anyhow::Result;
use axum::Extension;
use cryptopuz::{establish_connection, AppState, auth};

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    auth::ensure_jwt_secret_is_valid();
    let rng = ring::rand::SystemRandom::new();
    let hmac_key = ring::hmac::Key::generate(ring::hmac::HMAC_SHA256, &rng)
        .expect("Unable to generate HMAC key");

    let db_pool = establish_connection(&env::var("DATABASE_URL").unwrap());
    let app = cryptopuz::app().with_state(AppState { db_pool, hmac_key });

    axum::Server::bind(&([0, 0, 0, 0], 8080).into())
        .serve(app.into_make_service())
        .await
        .unwrap();
}
