// @generated automatically by Diesel CLI.

diesel::table! {
    messages (id) {
        id -> Int4,
        message -> Varchar,
        attribution -> Nullable<Varchar>,
    }
}

diesel::table! {
    users (id) {
        id -> Varchar,
        username -> Varchar,
        password_hash -> Varchar,
        solved -> Int4,
    }
}

diesel::allow_tables_to_appear_in_same_query!(
    messages,
    users,
);
