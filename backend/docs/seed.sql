ALTER TABLE users ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT TRUE;
UPDATE users SET active = TRUE WHERE active IS NULL;

INSERT INTO rates (id, organik_per_kg, anorganik_per_kg, updated_at)
VALUES (1, 40, 100, UTC_TIMESTAMP(3))
ON DUPLICATE KEY UPDATE id = VALUES(id);

INSERT INTO machines (id, code, name, location, status, organic_fill, inorganic_fill, last_seen, created_at, updated_at)
VALUES (
  UUID(),
  'bin-01',
  'SmartBIN Unit #01',
  'Lokasi Demo SmartBIN',
  'OFFLINE',
  0,
  0,
  NULL,
  UTC_TIMESTAMP(3),
  UTC_TIMESTAMP(3)
)
ON DUPLICATE KEY UPDATE code = VALUES(code);
