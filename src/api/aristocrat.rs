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
    auth::Auth,
    error::{AppError, AppResult},
    models::User,
    AppState,
};
use anyhow::anyhow;

use super::profile::ProfileResponse;

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

async fn new(State(state): State<AppState>, auth: Option<Auth>) -> AppResult<Json<NewResponse>> {
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
            auth.map(|c| c.0.uid.as_bytes().to_vec()).unwrap_or(vec![]),
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
struct ExpSource {
    name: String,
    amount: String,
    special: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct SubmitResponse {
    plaintext: String,
    time_taken: u128,
    profile: Option<ProfileResponse>,
    exp_sources: Option<Vec<ExpSource>>,
}

async fn submit(
    State(state): State<AppState>,
    auth: Option<Auth>,
    Json(req): Json<SubmitRequest>,
) -> AppResult<Json<SubmitResponse>> {
    use crate::schema::{messages, users};
    let conn = &mut state.db_pool.get().await?;

    if let Ok(()) = hmac::verify(
        &state.hmac_key,
        &[
            auth.as_ref()
                .map(|c| c.0.uid.as_bytes().to_vec())
                .unwrap_or(vec![]),
            req.id.to_le_bytes().to_vec(),
            req.timestamp.to_le_bytes().to_vec(),
            req.message.to_lowercase().as_bytes().to_vec(),
        ]
        .concat(),
        &base64::decode(req.sig.as_bytes().to_vec())?,
    ) {
        let time_taken = get_timestamp() - req.timestamp;
        if let Some(Auth(claims)) = auth {
            let solve_exp = 100;
            let time_taken_sec = (time_taken as f64) / 1000.0;
            let time_bonus =
                (100_f64 - ((time_taken_sec - 10.0).max(0.0) * 5.0/3.0)).max(0.0) as i32;

            let sum = solve_exp + time_bonus;
            let mut exp_sources = vec![ExpSource {
                name: String::from("Solve"),
                amount: format!("+{}", solve_exp),
                special: false,
            }];

            if time_bonus > 0 {
                exp_sources.push(ExpSource {
                    name: String::from("Time Bonus"),
                    amount: format!("+{}", time_bonus),
                    special: false,
                });
            }

            let user = diesel::update(users::table)
                .filter(users::id.eq(claims.uid))
                .set((
                    users::experience.eq(users::experience + sum),
                    users::solved.eq(users::solved + 1),
                ))
                .get_result::<User>(conn)
                .await
                .optional()?;

            return Ok(Json(SubmitResponse {
                plaintext: messages::table
                    .select(messages::message)
                    .filter(messages::id.eq(req.id))
                    .first::<String>(conn)
                    .await?,
                time_taken,
                profile: user.map(ProfileResponse::from),
                exp_sources: Some(exp_sources),
            }));
        } else {
            return Ok(Json(SubmitResponse {
                plaintext: messages::table
                    .select(messages::message)
                    .filter(messages::id.eq(req.id))
                    .first::<String>(conn)
                    .await?,
                time_taken,
                profile: None,
                exp_sources: None,
            }));
        }
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
