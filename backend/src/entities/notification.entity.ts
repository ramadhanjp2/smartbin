import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from "typeorm";
import { UserEntity } from "./user.entity";

@Entity("notifications")
export class NotificationEntity {
  @PrimaryGeneratedColumn("uuid")
  id!: string;

  @Column({ name: "user_id", type: "varchar", length: 36 })
  userId!: string;

  @ManyToOne(() => UserEntity, (user) => user.notifications, {
    onDelete: "CASCADE",
  })
  @JoinColumn({ name: "user_id" })
  user!: UserEntity;

  @Column({ type: "varchar", length: 32 })
  kind!: string;

  @Column({ length: 160 })
  title!: string;

  @Column({ type: "text" })
  body!: string;

  @Column({ name: "reference_id", type: "varchar", length: 100, nullable: true })
  referenceId!: string | null;

  @Column({ name: "is_read", type: "boolean", default: false })
  isRead!: boolean;

  @CreateDateColumn({ name: "created_at", precision: 3 })
  createdAt!: Date;
}
