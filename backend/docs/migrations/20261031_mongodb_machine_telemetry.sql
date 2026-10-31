-- Machine telemetry is now sourced from MongoDB machine_latest.
-- Keep only machine identity and descriptive metadata in MySQL.
ALTER TABLE machines
  DROP INDEX idx_machines_status,
  DROP INDEX idx_machines_last_seen,
  DROP COLUMN status,
  DROP COLUMN organic_fill,
  DROP COLUMN inorganic_fill,
  DROP COLUMN residu_fill,
  DROP COLUMN organik_cm,
  DROP COLUMN anorganik_cm,
  DROP COLUMN residu_cm,
  DROP COLUMN last_seen;
