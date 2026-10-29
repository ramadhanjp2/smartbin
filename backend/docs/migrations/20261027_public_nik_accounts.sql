-- Prepare public accounts and remove legacy campus/NIM scope.
ALTER TABLE users DROP COLUMN IF EXISTS nim;
ALTER TABLE machines DROP COLUMN IF EXISTS campus;
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS nik_hash varchar(64) NULL AFTER email,
  ADD UNIQUE KEY IF NOT EXISTS uq_users_nik_hash (nik_hash);

-- Query indexes for the most common MySQL access paths.
CREATE INDEX idx_deposits_user_device_time ON deposits (user_id, device_time);
CREATE INDEX idx_deposits_machine_received_at ON deposits (machine_id, received_at);
CREATE INDEX idx_point_ledger_user_created_at ON point_ledger (user_id, created_at);
CREATE INDEX idx_notifications_user_read_created_at ON notifications (user_id, is_read, created_at);
CREATE INDEX idx_refresh_sessions_user_expires_at ON refresh_sessions (user_id, expires_at);
CREATE INDEX idx_machines_status ON machines (status);
CREATE INDEX idx_machines_last_seen ON machines (last_seen);
