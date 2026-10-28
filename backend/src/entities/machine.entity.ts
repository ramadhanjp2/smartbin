import {
  Column,
  CreateDateColumn,
  Entity,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";
import { DepositEntity } from "./deposit.entity";

export type MachineStatus = "SIAP" | "PENUH" | "GANGGUAN" | "OFFLINE";

@Entity("machines")
export class MachineEntity {
  @PrimaryGeneratedColumn("uuid")
  id!: string;

  @Column({ unique: true, length: 80 })
  code!: string;

  @Column({ length: 120 })
  name!: string;

  @Column({ length: 120, default: "" })
  campus!: string;

  @Column({ length: 255 })
  location!: string;

  @Column({
    type: "enum",
    enum: ["SIAP", "PENUH", "GANGGUAN", "OFFLINE"],
    default: "OFFLINE",
  })
  status!: MachineStatus;

  @Column({ name: "organic_fill", type: "tinyint", unsigned: true, default: 0 })
  organicFill!: number;

  @Column({
    name: "inorganic_fill",
    type: "tinyint",
    unsigned: true,
    default: 0,
  })
  inorganicFill!: number;

  @Column({ name: "last_seen", type: "datetime", precision: 3, nullable: true })
  lastSeen!: Date | null;

  @OneToMany(() => DepositEntity, (deposit) => deposit.machine)
  deposits!: DepositEntity[];

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
