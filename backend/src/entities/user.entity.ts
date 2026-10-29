import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  OneToMany,
  OneToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";
import { CardEntity } from "./card.entity";
import { DepositEntity } from "./deposit.entity";
import { NotificationEntity } from "./notification.entity";
import { PointLedgerEntity } from "./point-ledger.entity";
import { RefreshSessionEntity } from "./refresh-session.entity";

export type UserRole = "user" | "admin";

@Entity("users")
export class UserEntity {
  @PrimaryGeneratedColumn("uuid")
  id!: string;

  @Column({ unique: true, length: 254 })
  email!: string;

  @Index("uq_users_nik_hash", { unique: true })
  @Column({
    name: "nik_hash",
    type: "varchar",
    length: 64,
    nullable: true,
    select: false,
  })
  nikHash!: string | null;

  @Column({ length: 120 })
  name!: string;

  @Column({ name: "password_hash", select: false, length: 255 })
  passwordHash!: string;

  @Column({ type: "enum", enum: ["user", "admin"], default: "user" })
  role!: UserRole;

  @OneToOne(() => CardEntity, (card) => card.user)
  card?: CardEntity | null;

  @OneToMany(() => DepositEntity, (deposit) => deposit.user)
  deposits!: DepositEntity[];

  @OneToMany(() => PointLedgerEntity, (entry) => entry.user)
  ledger!: PointLedgerEntity[];

  @OneToMany(() => NotificationEntity, (notification) => notification.user)
  notifications!: NotificationEntity[];

  @OneToMany(() => RefreshSessionEntity, (session) => session.user)
  sessions!: RefreshSessionEntity[];

  @CreateDateColumn({
    name: "created_at",
    precision: 3,
    default: () => "CURRENT_TIMESTAMP(3)",
  })
  createdAt!: Date;

  @UpdateDateColumn({
    name: "updated_at",
    precision: 3,
    default: () => "CURRENT_TIMESTAMP(3)",
    onUpdate: "CURRENT_TIMESTAMP(3)",
  })
  updatedAt!: Date;
}
