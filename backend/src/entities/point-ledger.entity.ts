import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from "typeorm";
import { UserEntity } from "./user.entity";

@Entity("point_ledger")
@Index(["userId", "createdAt"])
@Index(["reason", "referenceId"], { unique: true })
export class PointLedgerEntity {
  @PrimaryGeneratedColumn("uuid")
  id!: string;

  @Column({ name: "user_id", type: "varchar", length: 36 })
  userId!: string;

  @ManyToOne(() => UserEntity, (user) => user.ledger, { onDelete: "CASCADE" })
  @JoinColumn({ name: "user_id" })
  user!: UserEntity;

  @Column({ type: "int" })
  delta!: number;

  @Column({ type: "enum", enum: ["DEPOSIT", "REDEEM", "ADJUST"] })
  reason!: "DEPOSIT" | "REDEEM" | "ADJUST";

  @Column({ name: "reference_id", type: "varchar", length: 100 })
  referenceId!: string;

  @CreateDateColumn({ name: "created_at", precision: 3 })
  createdAt!: Date;
}
