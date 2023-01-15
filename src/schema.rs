// @generated automatically by Diesel CLI.

diesel::table! {
    messages (id) {
        id -> Int4,
        message -> Varchar,
        patristocrat_hint -> Nullable<Varchar>,
        attribution -> Nullable<Varchar>,
    }
}

diesel::table! {
    solves (id) {
        id -> Int4,
        puzzle_type -> Int2,
        message_id -> Int4,
        solver -> Varchar,
        time_taken -> Int4,
        exp_gained -> Int4,
    }
}

diesel::table! {
    users (id) {
        id -> Varchar,
        username -> Varchar,
        email -> Nullable<Varchar>,
        password_hash -> Varchar,
        solved -> Int4,
        experience -> Int4,
    }
}

diesel::joinable!(solves -> messages (message_id));
diesel::joinable!(solves -> users (solver));

diesel::allow_tables_to_appear_in_same_query!(
    messages,
    solves,
    users,
);
