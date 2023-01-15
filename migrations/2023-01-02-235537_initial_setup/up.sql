CREATE TABLE IF NOT EXISTS messages(
    id SERIAL PRIMARY KEY,
    message VARCHAR(255) NOT NULL UNIQUE,
    patristocrat_hint VARCHAR(255),
    attribution VARCHAR(127)
);

CREATE TABLE IF NOT EXISTS users(
    id VARCHAR(24) PRIMARY KEY,
    username VARCHAR(32) NOT NULL UNIQUE,
    email VARCHAR(127),
    password_hash VARCHAR(127) NOT NULL,
    solved INTEGER NOT NULL DEFAULT 0,
    experience INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS solves(
    id SERIAL PRIMARY KEY,
    puzzle_type SMALLINT NOT NULL,
    message_id INT NOT NULL REFERENCES messages(id),
    solver VARCHAR(24) NOT NULL REFERENCES users(id),
    time_taken INT NOT NULL,
    exp_gained INT NOT NULL
)