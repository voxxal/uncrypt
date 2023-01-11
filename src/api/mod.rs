use axum::Router;
use serde::Serialize;

use crate::{AppState, exp::ExpSource};

use self::profile::ProfileResponse;

pub mod aristocrat;
pub mod baconian;
pub mod auth;
pub mod profile;

pub fn app() -> Router<AppState> {
    Router::new()
        .nest("/aristocrat", aristocrat::app())
        .nest("/baconian",  baconian::app())
        .nest("/profile", profile::app())
        .nest("/auth", auth::app())
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SubmitResponse {
    plaintext: String,
    time_taken: u128,
    profile: Option<ProfileResponse>,
    exp_sources: Option<Vec<ExpSource>>,
}
