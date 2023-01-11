use std::time::{SystemTime, UNIX_EPOCH};

use diesel::sql_function;
use ring::hmac;

use crate::auth::Auth;

pub fn get_timestamp() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("time went backwards")
        .as_millis()
}

pub fn generate_sig(
    hmac_key: &hmac::Key,
    auth: &Option<Auth>,
    msg_id: i32,
    timestamp: u128,
    msg: String,
) -> String {
    base64::encode(&hmac::sign(
        hmac_key,
        &[
            auth.as_ref()
                .map(|c| c.0.uid.as_bytes().to_vec())
                .unwrap_or(vec![]),
            msg_id.to_le_bytes().to_vec(),
            timestamp.to_le_bytes().to_vec(),
            msg.to_lowercase().as_bytes().to_vec(),
        ]
        .concat(),
    ))
}

pub fn verify_solution(
    hmac_key: &hmac::Key,
    auth: &Option<Auth>,
    msg_id: i32,
    timestamp: u128,
    msg: String,
    sig: String,
) -> anyhow::Result<bool> {
    Ok(hmac::verify(
        hmac_key,
        &[
            auth.as_ref()
                .map(|c| c.0.uid.as_bytes().to_vec())
                .unwrap_or(vec![]),
            msg_id.to_le_bytes().to_vec(),
            timestamp.to_le_bytes().to_vec(),
            msg.to_lowercase().as_bytes().to_vec(),
        ]
        .concat(),
        &base64::decode(sig.as_bytes().to_vec())?,
    )
    .is_ok())
}

sql_function!(fn random() -> Text);
