INSERT INTO rates (id, organik_per_kg, anorganik_per_kg, updated_at)
VALUES (1, 40, 100, UTC_TIMESTAMP(3))
ON DUPLICATE KEY UPDATE id = VALUES(id);

INSERT INTO machines (id, code, name, campus, location, status, organic_fill, inorganic_fill, last_seen, created_at, updated_at)
VALUES (
  UUID(),
  'bin-01',
  'SmartBIN Unit #01',
  'UI',
  'Perpustakaan Pusat',
  'OFFLINE',
  0,
  0,
  NULL,
  UTC_TIMESTAMP(3),
  UTC_TIMESTAMP(3)
)
ON DUPLICATE KEY UPDATE code = VALUES(code);
