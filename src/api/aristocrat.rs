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
struct NewResponse {
    id: i32,
    ciphertext: String, // TODO return as an array instead
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

async fn new(State(state): State<AppState>) -> AppResult<Json<NewResponse>> {
    use crate::schema::messages::dsl::*;
    let conn = &mut state.db_pool.get().await?;

    let msg_info = messages
        .select((id, message, attribution))
        .order(random())
        .first::<(i32, String, Option<String>)>(conn)
        .await
        .optional()?;

    let Some(msg_info) = msg_info else {
        return Err(anyhow!("expected 1 message in database").into())
    };

    let sub_alphabet = random_sub_alphabet();

    let ciphertext: String = msg_info
        .1
        .chars()
        .map(|c| *sub_alphabet.get(&c.to_ascii_lowercase()).unwrap_or(&c))
        .collect();

    let timestamp = get_timestamp();

    let tag = hmac::sign(
        &state.hmac_key,
        &[
            msg_info.0.to_le_bytes().to_vec(),
            timestamp.to_le_bytes().to_vec(),
            msg_info.1.to_lowercase().as_bytes().to_vec(),
        ]
        .concat(),
    );

    Ok(Json(NewResponse {
        id: msg_info.0,
        ciphertext,
        sig: base64::encode(tag.as_ref()),
        timestamp,
        attribution: msg_info.2.unwrap_or("Unknown".to_string()),
    }))
}

#[derive(Deserialize)]
struct SubmitRequest {
    id: i32,
    message: String,
    sig: String,
    timestamp: u128,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct SubmitResponse {
    plaintext: String,
    time_taken: u128,
}

async fn submit(
    State(state): State<AppState>,
    Json(req): Json<SubmitRequest>,
) -> AppResult<Json<SubmitResponse>> {
    use crate::schema::messages::dsl::*;
    let conn = &mut state.db_pool.get().await?;

    if let Ok(()) = hmac::verify(
        &state.hmac_key,
        &[
            req.id.to_le_bytes().to_vec(),
            req.timestamp.to_le_bytes().to_vec(),
            req.message.to_lowercase().as_bytes().to_vec(),
        ]
        .concat(),
        &base64::decode(req.sig.as_bytes().to_vec())?,
    ) {
        // How do i get the plaintext out of only the sig and timestamp? either i need the puzzle id or some other sort of identifier
        // if i include the puzzle id, i'm afraid that you can use that to just solve the puzzle instantly.
        return Ok(Json(SubmitResponse {
            plaintext: messages
                .select(message)
                .filter(id.eq(req.id))
                .first::<String>(conn)
                .await?,
            time_taken: get_timestamp() - req.timestamp,
        }));
    }

    Err(AppError::from(
        StatusCode::EXPECTATION_FAILED,
        "The puzzle is incorrect",
    ))
}

pub fn app() -> Router<AppState> {
    Router::new()
        .route("/new", get(new))
        .route("/submit", post(submit))
}
