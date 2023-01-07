-- TODO make a better primary key not username
CREATE TABLE IF NOT EXISTS users(
    id VARCHAR(24) PRIMARY KEY,
    username VARCHAR(32) NOT NULL UNIQUE,
    email VARCHAR(127),
    password_hash VARCHAR(127) NOT NULL,
    solved INTEGER NOT NULL DEFAULT 0
)