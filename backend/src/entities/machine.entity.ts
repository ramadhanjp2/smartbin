import {
  Column,
  CreateDateColumn,
  Entity,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";
import { DepositEntity } from "./deposit.entity";

@Entity("machines")
export class MachineEntity {
  @PrimaryGeneratedColumn("uuid")
  id!: string;

  @Column({ unique: true, length: 80 })
  code!: string;

  @Column({ length: 120 })
  name!: string;

  @Column({ length: 255 })
  location!: string;

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
