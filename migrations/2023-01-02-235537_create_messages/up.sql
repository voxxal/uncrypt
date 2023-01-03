CREATE TABLE IF NOT EXISTS messages(
    id SERIAL PRIMARY KEY,
    message VARCHAR(255) NOT NULL UNIQUE,
    patristocrat_hint VARCHAR(255),
    attribution VARCHAR(127)
)