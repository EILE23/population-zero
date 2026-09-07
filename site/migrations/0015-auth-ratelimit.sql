CREATE TABLE IF NOT EXISTS auth_attempts (ip TEXT NOT NULL, ts TEXT NOT NULL DEFAULT (datetime('now')));
CREATE INDEX IF NOT EXISTS idx_auth_attempts ON auth_attempts(ip, ts);
