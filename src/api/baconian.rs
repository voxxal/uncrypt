use std::collections::HashMap;

use axum::{
    extract::State,
    http::StatusCode,
    routing::{get, post},
    Json, Router,
};
use bitvec::prelude::*;
use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use lazy_static::lazy_static;
use rand::thread_rng;
use rand::{seq::SliceRandom, Rng};
use serde::{Deserialize, Serialize};

use crate::{
    auth::Auth,
    error::{AppError, AppResult},
    exp::ExpSource,
    models::User,
    util::{generate_sig, get_timestamp, random, verify_solution},
    AppState,
};
use anyhow::anyhow;

use super::{profile::ProfileResponse, SubmitResponse};

lazy_static! {
    static ref BACONIAN: HashMap<char, BitArray<[u8; 1], Msb0>> = HashMap::from([
        ('a', bitarr![u8, Msb0; 0, 0, 0, 0, 0]),
        ('b', bitarr![u8, Msb0; 0, 0, 0, 0, 1]),
        ('c', bitarr![u8, Msb0; 0, 0, 0, 1, 0]),
        ('d', bitarr![u8, Msb0; 0, 0, 0, 1, 1]),
        ('e', bitarr![u8, Msb0; 0, 0, 1, 0, 0]),
        ('f', bitarr![u8, Msb0; 0, 0, 1, 0, 1]),
        ('g', bitarr![u8, Msb0; 0, 0, 1, 1, 0]),
        ('h', bitarr![u8, Msb0; 0, 0, 1, 1, 1]),
        ('i', bitarr![u8, Msb0; 0, 1, 0, 0, 0]),
        ('j', bitarr![u8, Msb0; 0, 1, 0, 0, 0]),
        ('k', bitarr![u8, Msb0; 0, 1, 0, 0, 1]),
        ('l', bitarr![u8, Msb0; 0, 1, 0, 1, 0]),
        ('m', bitarr![u8, Msb0; 0, 1, 0, 1, 1]),
        ('n', bitarr![u8, Msb0; 0, 1, 1, 0, 0]),
        ('o', bitarr![u8, Msb0; 0, 1, 1, 0, 1]),
        ('p', bitarr![u8, Msb0; 0, 1, 1, 1, 0]),
        ('q', bitarr![u8, Msb0; 0, 1, 1, 1, 1]),
        ('r', bitarr![u8, Msb0; 1, 0, 0, 0, 0]),
        ('s', bitarr![u8, Msb0; 1, 0, 0, 0, 1]),
        ('t', bitarr![u8, Msb0; 1, 0, 0, 1, 0]),
        ('u', bitarr![u8, Msb0; 1, 0, 0, 1, 1]),
        ('v', bitarr![u8, Msb0; 1, 0, 0, 1, 1]),
        ('w', bitarr![u8, Msb0; 1, 0, 1, 0, 0]),
        ('x', bitarr![u8, Msb0; 1, 0, 1, 0, 1]),
        ('y', bitarr![u8, Msb0; 1, 0, 1, 1, 0]),
        ('z', bitarr![u8, Msb0; 1, 0, 1, 1, 1]),
    ]);
    static ref VARIANTS: [[Vec<char>; 2]; 4] = [
        [vec!['A'], vec!['B']],
        [vec!['0'], vec!['1']],
        [('a'..='m').collect(), ('n'..='z').collect()],
        [('a'..='z').collect(), ('0'..='9').collect()]
    ];
}

fn random_variant() -> [Vec<char>; 2] {
    let mut rng = thread_rng();
    let mut variant = VARIANTS
        .choose(&mut rng)
        .expect("needs at least 1 variant")
        .clone();

    if rng.gen::<f32>() >= 0.5 {
        variant.swap(0, 1);
    }

    variant
}

fn encode(variant: &[Vec<char>; 2], c: char) -> Option<String> {
    let mut rng = thread_rng();
    let Some(encoding) = BACONIAN.get(&c) else {
        return None;
    };

    let mut buf = String::with_capacity(5);
    for i in 0..5 {
        let bit = encoding[i];
        buf.push(
            *variant[bit as usize]
                .choose(&mut rng)
                .expect("parts of variant should have at least 1 option"),
        );
    }

    Some(buf)
}

#[derive(Serialize)]
struct NewResponse {
    id: i32,
    ciphertext: Vec<String>,
    sig: String,
    timestamp: u128,
    attribution: String,
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

    let variant = random_variant();

    let ciphertext: Vec<String> = message
        .to_lowercase()
        .chars()
        .filter_map(|c| encode(&variant, c))
        .collect();

    let timestamp = get_timestamp();

    let sig = generate_sig(
        &state.hmac_key,
        &auth,
        msg_id,
        timestamp,
        message.chars().filter(|c| c.is_alphabetic()).collect(),
    );

    Ok(Json(NewResponse {
        id: msg_id,
        ciphertext,
        sig,
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
    use crate::schema::{messages, users};
    let conn = &mut state.db_pool.get().await?;

    if verify_solution(
        &state.hmac_key,
        &auth,
        req.id,
        req.timestamp,
        req.message.chars().filter(|c| c.is_alphabetic()).collect(),
        req.sig,
    )? {
        let time_taken = get_timestamp() - req.timestamp;
        if let Some(Auth(claims)) = auth {
            let solve_exp = 75;
            let time_taken_sec = (time_taken as f64) / 1000.0;
            let time_bonus =
                (100_f64 - ((time_taken_sec - 10.0).max(0.0) * 2.5 / 3.0)).max(0.0) as i32;

            let sum = solve_exp + time_bonus;
            let mut exp_sources = vec![ExpSource::additive("Solve", solve_exp)];

            if time_bonus > 0 {
                exp_sources.push(ExpSource::additive("Time Bonus", time_bonus));
            }

            let user = diesel::update(users::table)
                .filter(users::id.eq(claims.uid))
                .set((
                    users::experience.eq(users::experience + sum),
                    users::solved.eq(users::solved + 1),
                ))
                .get_result::<User>(conn)
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
