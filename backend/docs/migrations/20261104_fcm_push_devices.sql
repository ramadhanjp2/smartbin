-- Inherit the database charset/collation so user_id matches users.id for its FK.
CREATE TABLE push_devices (
  id varchar(36) NOT NULL,
  user_id varchar(36) NOT NULL,
  token_hash char(64) NOT NULL,
  token text NOT NULL,
  created_at timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_push_devices_token_hash (token_hash),
  KEY ix_push_devices_user_id (user_id),
  CONSTRAINT fk_push_devices_user
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB;
