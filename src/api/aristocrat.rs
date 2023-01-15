use std::collections::HashMap;

use axum::{
    extract::State,
    http::StatusCode,
    routing::{get, post},
    Json, Router,
};
use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use rand::seq::SliceRandom;
use rand::thread_rng;
use serde::{Deserialize, Serialize};

use crate::{
    api::{NewSolve, PuzzleType},
    auth::Auth,
    error::{AppError, AppResult},
    exp::ExpSource,
    models::User,
    util::{generate_sig, get_timestamp, random, verify_solution},
    AppState,
};
use anyhow::anyhow;

use super::{profile::ProfileResponse, SubmitResponse};

type SubAlphabet = HashMap<char, char>;

const ALPHABET: [char; 26] = [
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's',
    't', 'u', 'v', 'w', 'x', 'y', 'z',
];

#[derive(Serialize)]
struct NewResponse {
    id: i32,
    ciphertext: String, // TODO return as an array instead
    sig: String,
    timestamp: u128,
    attribution: String,
}

fn random_sub_alphabet() -> SubAlphabet {
    let mut rng = thread_rng();
    let mut shuffled = ALPHABET.clone();
    shuffled.shuffle(&mut rng);
    ALPHABET.zip(shuffled).into_iter().collect()
}

async fn new(State(state): State<AppState>, auth: Option<Auth>) -> AppResult<Json<NewResponse>> {
    use crate::schema::messages;
    let conn = &mut state.db_pool.get().await?;

    let Some((msg_id, message, attribution)) = messages::table
        .select((messages::id, messages::message, messages::attribution))
        .order(random())
        .first::<(i32, String, Option<String>)>(conn)
        .await
        .optional()? else {
            return Err(anyhow!("expected 1 message in database").into())
        };

    let sub_alphabet = random_sub_alphabet();

    let ciphertext: String = message
        .chars()
        .map(|c| *sub_alphabet.get(&c.to_ascii_lowercase()).unwrap_or(&c))
        .collect();

    let timestamp = get_timestamp();

    Ok(Json(NewResponse {
        id: msg_id,
        ciphertext,
        sig: generate_sig(&state.hmac_key, &auth, msg_id, timestamp, message),
        timestamp,
        attribution: attribution.unwrap_or("Unknown".to_string()),
    }))
}

#[derive(Deserialize)]
struct SubmitRequest {
    id: i32,
    message: String,
    sig: String,
    timestamp: u128,
}

async fn submit(
    State(state): State<AppState>,
    auth: Option<Auth>,
    Json(req): Json<SubmitRequest>,
) -> AppResult<Json<SubmitResponse>> {
    use crate::schema::{messages, solves, users};
    let conn = &mut state.db_pool.get().await?;

    if verify_solution(
        &state.hmac_key,
        &auth,
        req.id,
        req.timestamp,
        req.message,
        req.sig,
    )? {
        let time_taken = get_timestamp() - req.timestamp;
        if let Some(Auth(claims)) = auth {
            let solve_exp = 100;
            let time_taken_sec = (time_taken as f64) / 1000.0;
            let time_bonus =
                (100_f64 - ((time_taken_sec - 10.0).max(0.0) * 5.0 / 3.0)).max(0.0) as i32;

            let sum = solve_exp + time_bonus;
            let mut exp_sources = vec![ExpSource::additive("Solve", solve_exp)];

            if time_bonus > 0 {
                exp_sources.push(ExpSource::additive("Time Bonus", time_bonus));
            }

            // TODO total and save to table to display recent solves
            let user = diesel::update(users::table)
                .filter(users::id.eq(claims.uid))
                .set((
                    users::experience.eq(users::experience + sum),
                    users::solved.eq(users::solved + 1),
                ))
                .get_result::<User>(conn)
                .await?;

            diesel::insert_into(solves::table)
                .values(NewSolve::new(
                    PuzzleType::Aristocrat,
                    req.id,
                    &user,
                    time_taken as i32,
                    sum,
                ))
                .execute(conn)
                .await?;

            return Ok(Json(SubmitResponse {
                plaintext: messages::table
                    .select(messages::message)
                    .filter(messages::id.eq(req.id))
                    .first::<String>(conn)
                    .await?,
                time_taken,
                profile: Some(ProfileResponse::from(user)),
                exp_sources: Some(exp_sources),
                total_exp: Some(sum),
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
                total_exp: None,
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
