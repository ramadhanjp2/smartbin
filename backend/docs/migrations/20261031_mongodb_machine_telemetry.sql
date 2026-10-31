-- Machine telemetry is now sourced from MongoDB machine_latest.
-- Keep only machine identity and descriptive metadata in MySQL.
-- MySQL removes indexes that reference a dropped column automatically.
ALTER TABLE machines
  DROP COLUMN status,
  DROP COLUMN organic_fill,
  DROP COLUMN inorganic_fill,
  DROP COLUMN residu_fill,
  DROP COLUMN organik_cm,
  DROP COLUMN anorganik_cm,
  DROP COLUMN residu_cm,
  DROP COLUMN last_seen;
