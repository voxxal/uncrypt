use std::{
    collections::HashMap,
    time::{SystemTime, UNIX_EPOCH},
};

use axum::{routing::get, Extension, Json, Router};
use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use rand::seq::SliceRandom;
use rand::thread_rng;
use ring::hmac;
use serde::{Deserialize, Serialize};

use crate::{error::AppResult, models::Message, DbPool};
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
    attribution: Option<String>,
}

fn random_sub_alphabet() -> SubAlphabet {
    let mut rng = thread_rng();
    let mut shuffled = ALPHABET.clone();
    shuffled.shuffle(&mut rng);
    ALPHABET.zip(shuffled).into_iter().collect()
}

async fn get_aristocrat(
    Extension(pool): Extension<DbPool>,
    Extension(hmac_key): Extension<hmac::Key>,
) -> AppResult<Json<AristocratResponse>> {
    use crate::schema::messages::dsl::*;
    let conn = &mut pool.get().await?;

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

    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards")
        .as_millis();

    // The timestamp is always 16 bytes, so we can split there to get the timestamp
    let tag = hmac::sign(
        &hmac_key,
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
        attribution: msg_info.1,
    }))
}

#[derive(Deserialize)]
struct AristocratCompleteRequest {
    message: String,
    sig: String,
    timestamp: u128,
}

#[axum::debug_handler]
async fn post_aristocrat(
    Extension(hmac_key): Extension<hmac::Key>,
    Json(req): Json<AristocratCompleteRequest>,
) -> AppResult<Json<u128>> {
    if let Ok(()) = hmac::verify(
        &hmac_key,
        &[
            req.timestamp.to_le_bytes().to_vec(),
            req.message.to_lowercase().as_bytes().to_vec(),
        ]
        .concat(),
        &base64::decode(req.sig.as_bytes().to_vec())?,
    ) {
        return Ok(Json(req.timestamp));
    }

    Err(anyhow!("Something went wrong").into())
}

pub fn app() -> Router {
    Router::new().route("/aristocrat", get(get_aristocrat).post(post_aristocrat))
}
