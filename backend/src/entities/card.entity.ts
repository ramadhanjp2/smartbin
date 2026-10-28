import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryColumn,
} from "typeorm";
import { UserEntity } from "./user.entity";

@Entity("cards")
export class CardEntity {
  @PrimaryColumn({ name: "user_id", type: "varchar", length: 36 })
  userId!: string;

  @OneToOne(() => UserEntity, (user) => user.card, { onDelete: "CASCADE" })
  @JoinColumn({ name: "user_id" })
  user!: UserEntity;

  @Column({ name: "uid_hash", unique: true, length: 64 })
  uidHash!: string;

  @CreateDateColumn({
    name: "linked_at",
    precision: 3,
    default: () => "CURRENT_TIMESTAMP(3)",
  })
  linkedAt!: Date;
}
