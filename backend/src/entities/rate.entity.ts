import { Column, Entity, PrimaryColumn, UpdateDateColumn } from "typeorm";

@Entity("rates")
export class RateEntity {
  @PrimaryColumn({ type: "tinyint", unsigned: true, default: 1 })
  id!: number;

  @Column({ name: "organik_per_kg", type: "int", unsigned: true, default: 40 })
  organikPerKg!: number;

  @Column({
    name: "anorganik_per_kg",
    type: "int",
    unsigned: true,
    default: 100,
  })
  anorganikPerKg!: number;

  @UpdateDateColumn({
    name: "updated_at",
    precision: 3,
    default: () => "CURRENT_TIMESTAMP(3)",
    onUpdate: "CURRENT_TIMESTAMP(3)",
  })
  updatedAt!: Date;
}
