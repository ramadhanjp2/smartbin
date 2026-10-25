import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from "typeorm";
import { UserEntity } from "./user.entity";

@Entity("refresh_sessions")
export class RefreshSessionEntity {
  @PrimaryGeneratedColumn("uuid")
  id!: string;

  @Column({ name: "user_id", type: "varchar", length: 36 })
  userId!: string;

  @ManyToOne(() => UserEntity, (user) => user.sessions, { onDelete: "CASCADE" })
  @JoinColumn({ name: "user_id" })
  user!: UserEntity;

  @Column({ name: "token_hash", unique: true, length: 64 })
  tokenHash!: string;

  @Column({ name: "expires_at", type: "datetime", precision: 3 })
  expiresAt!: Date;

  @Column({
    name: "revoked_at",
    type: "datetime",
    precision: 3,
    nullable: true,
  })
  revokedAt!: Date | null;

  @CreateDateColumn({ name: "created_at", precision: 3 })
  createdAt!: Date;
}
