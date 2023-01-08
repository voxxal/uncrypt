use std::{env, time::Duration};

use argon2::Argon2;
use axum::{
    async_trait,
    extract::FromRequestParts,
    headers::{authorization::Bearer, Authorization},
    http::{request::Parts, StatusCode},
    RequestPartsExt, TypedHeader,
};
use jsonwebtoken::{errors::Result as JwtResult, DecodingKey, EncodingKey};
use lazy_static::{__Deref, lazy_static};
use password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString};
use serde::{Deserialize, Serialize};

use crate::{error::ResponseStatusError, models::User};

pub fn hash_password(password: impl AsRef<[u8]>) -> password_hash::Result<String> {
    let salt = SaltString::generate(&mut OsRng);
    Argon2::default()
        .hash_password(password.as_ref(), &salt)
        .map(|h| h.to_string())
}

pub fn verify_password(
    password: impl AsRef<[u8]>,
    password_hash: impl AsRef<str>,
) -> password_hash::Result<bool> {
    let parsed_hash = PasswordHash::new(password_hash.as_ref())?;
    Ok(Argon2::default()
        .verify_password(password.as_ref(), &parsed_hash)
        .is_ok())
}

struct Keys {
    encoding: EncodingKey,
    decoding: DecodingKey,
}

lazy_static! {
    static ref KEYS: Keys = {
        let secret = env::var("JWT_SECRET").expect("JWT_SECRET must be set");
        Keys {
            encoding: EncodingKey::from_base64_secret(&secret)
                .expect("JWT_SECRET is not valid base64"),
            decoding: DecodingKey::from_base64_secret(&secret)
                .expect("JWT_SECRET is not valid base64"),
        }
    };
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Claims {
    pub uid: String,
    pub username: String,
    pub iat: u64,
    pub exp: u64,
}

#[allow(unused_must_use)]
pub fn ensure_jwt_secret_is_valid() {
    KEYS.deref();
}

pub fn generate_jwt(user: &User, exp: Duration) -> JwtResult<String> {
    let timestamp = jsonwebtoken::get_current_timestamp();
    jsonwebtoken::encode(
        &Default::default(),
        &Claims {
            uid: user.id.clone(),
            username: user.username.clone(),
            iat: timestamp,
            exp: timestamp + exp.as_secs(),
        },
        &KEYS.encoding,
    )
}

#[derive(Debug, Clone)]
pub struct Auth(pub Claims);

#[async_trait]
impl<S> FromRequestParts<S> for Auth
where
    S: Send + Sync,
{
    type Rejection = ResponseStatusError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let TypedHeader(Authorization(bearer)) = parts
            .extract::<TypedHeader<Authorization<Bearer>>>()
            .await
            .map_err(|_| (StatusCode::BAD_REQUEST, "missing credentials"))?;

        let claims =
            jsonwebtoken::decode::<Claims>(bearer.token(), &KEYS.decoding, &Default::default())
                .map_err(|_| (StatusCode::BAD_REQUEST, "invalid token"))?
                .claims;

        if claims.exp < jsonwebtoken::get_current_timestamp() {
            Err((StatusCode::UNAUTHORIZED, "token expired").into())
        } else {
            Ok(Auth(claims))
        }
    }
}
