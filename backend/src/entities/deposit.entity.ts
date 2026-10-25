import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from "typeorm";
import { MachineEntity } from "./machine.entity";
import { UserEntity } from "./user.entity";

export type WasteType = "ORGANIK" | "ANORGANIK";
export type DepositStatus = "HELD" | "CREDITED";

@Entity("deposits")
@Index(["userId", "deviceTime"])
export class DepositEntity {
  @PrimaryGeneratedColumn("uuid")
  id!: string;

  @Column({ name: "transaction_id", unique: true, length: 100 })
  transactionId!: string;

  @Column({ name: "machine_id", type: "varchar", length: 36 })
  machineId!: string;

  @ManyToOne(() => MachineEntity, (machine) => machine.deposits, {
    onDelete: "RESTRICT",
  })
  @JoinColumn({ name: "machine_id" })
  machine!: MachineEntity;

  @Column({ name: "user_id", type: "varchar", length: 36, nullable: true })
  userId!: string | null;

  @ManyToOne(() => UserEntity, (user) => user.deposits, {
    nullable: true,
    onDelete: "SET NULL",
  })
  @JoinColumn({ name: "user_id" })
  user!: UserEntity | null;

  @Column({ name: "uid_hash", length: 64 })
  uidHash!: string;

  @Column({ type: "enum", enum: ["ORGANIK", "ANORGANIK"] })
  type!: WasteType;

  @Column({ name: "item_label", length: 120, default: "" })
  itemLabel!: string;

  @Column({ name: "weight_g", type: "int", unsigned: true })
  weightG!: number;

  @Column({ type: "int", unsigned: true })
  points!: number;

  @Column({ name: "rate_per_kg", type: "int", unsigned: true })
  ratePerKg!: number;

  @Column({ name: "device_time", type: "datetime", precision: 3 })
  deviceTime!: Date;

  @CreateDateColumn({ name: "received_at", precision: 3 })
  receivedAt!: Date;

  @Column({ type: "enum", enum: ["HELD", "CREDITED"], default: "HELD" })
  status!: DepositStatus;
}
