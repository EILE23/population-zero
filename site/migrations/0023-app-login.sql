CREATE TABLE IF NOT EXISTS app_login_codes (
  code TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  challenge TEXT NOT NULL,
  expires_at TEXT NOT NULL
);
