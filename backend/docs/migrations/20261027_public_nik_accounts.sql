-- Run once before deploying the public NIK registration API.
-- Existing accounts retain their NIM and can continue logging in with NIM/email.
ALTER TABLE users
  MODIFY nim varchar(32) NULL,
  ADD COLUMN nik_hash varchar(64) NULL AFTER nim,
  ADD UNIQUE KEY uq_users_nik_hash (nik_hash);
