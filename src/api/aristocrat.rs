use std::{
    collections::HashMap,
    time::{SystemTime, UNIX_EPOCH},
};

use axum::{
    extract::State,
    http::StatusCode,
    routing::{get, post},
    Extension, Json, Router,
};
use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use rand::seq::SliceRandom;
use rand::thread_rng;
use ring::hmac;
use serde::{Deserialize, Serialize};

use crate::{
    error::{AppError, AppResult},
    AppState,
};
use anyhow::anyhow;

type SubAlphabet = HashMap<char, char>;

const ALPHABET: [char; 26] = [
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's',
    't', 'u', 'v', 'w', 'x', 'y', 'z',
];

sql_function!(fn random() -> Text);

#[derive(Serialize)]
struct AristocratResponse {
    message: String,
    sig: String,
    timestamp: u128,
    attribution: String,
}

fn get_timestamp() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("time went backwards")
        .as_millis()
}

fn random_sub_alphabet() -> SubAlphabet {
    let mut rng = thread_rng();
    let mut shuffled = ALPHABET.clone();
    shuffled.shuffle(&mut rng);
    ALPHABET.zip(shuffled).into_iter().collect()
}

async fn get_aristocrat(State(state): State<AppState>) -> AppResult<Json<AristocratResponse>> {
    use crate::schema::messages::dsl::*;
    let conn = &mut state.db_pool.get().await?;

    let msg_info = messages
        .select((message, attribution))
        .order(random())
        .limit(1)
        .load::<(String, Option<String>)>(conn)
        .await?
        .pop()
        .ok_or_else(|| anyhow!("expect at least one message"))?;

    let sub_alphabet = random_sub_alphabet();

    let ciphertext: String = msg_info
        .0
        .chars()
        .map(|c| *sub_alphabet.get(&c.to_ascii_lowercase()).unwrap_or(&c))
        .collect();

    let timestamp = get_timestamp();

    let tag = hmac::sign(
        &state.hmac_key,
        &[
            timestamp.to_le_bytes().to_vec(),
            msg_info.0.to_lowercase().as_bytes().to_vec(),
        ]
        .concat(),
    );

    Ok(Json(AristocratResponse {
        message: ciphertext,
        sig: base64::encode(tag.as_ref()),
        timestamp,
        attribution: msg_info.1.unwrap_or("Unknown".to_string()),
    }))
}

#[derive(Deserialize)]
struct AristocratSolutionSubmitRequest {
    message: String,
    sig: String,
    timestamp: u128,
}

async fn post_aristocrat(
    State(state): State<AppState>,
    Json(req): Json<AristocratSolutionSubmitRequest>,
) -> AppResult<Json<u128>> {
    if let Ok(()) = hmac::verify(
        &state.hmac_key,
        &[
            req.timestamp.to_le_bytes().to_vec(),
            req.message.to_lowercase().as_bytes().to_vec(),
        ]
        .concat(),
        &base64::decode(req.sig.as_bytes().to_vec())?,
    ) {
        return Ok(Json(get_timestamp() - req.timestamp));
    }

    Err(AppError::from(
        StatusCode::EXPECTATION_FAILED,
        "The puzzle is incorrect",
    ))
}

pub fn app() -> Router<AppState> {
    Router::new()
        .route("/new", get(get_aristocrat))
        .route("/submit", post(post_aristocrat))
}
