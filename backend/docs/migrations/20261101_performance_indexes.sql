-- Indeks untuk pencarian setoran HELD saat tautan KTP, pembersihan sesi kedaluwarsa,
-- dan penanda foto setoran (NULL = belum diperiksa; diisi otomatis oleh API).
-- Jalankan satu kali setelah backup.
ALTER TABLE deposits
  ADD COLUMN has_photo TINYINT(1) NULL DEFAULT NULL,
  ADD INDEX idx_deposits_uid_hash_status (uid_hash, status);

ALTER TABLE refresh_sessions
  ADD INDEX idx_refresh_sessions_expires_at (expires_at);
