// @generated automatically by Diesel CLI.

diesel::table! {
    messages (id) {
        id -> Int4,
        message -> Varchar,
        patristocrat_hint -> Nullable<Varchar>,
        attribution -> Nullable<Varchar>,
    }
}

diesel::allow_tables_to_appear_in_same_query!(messages,);
