import { Module } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { JwtModule } from "@nestjs/jwt";
import { ThrottlerGuard, ThrottlerModule } from "@nestjs/throttler";
import { TypeOrmModule } from "@nestjs/typeorm";
import { APP_GUARD } from "@nestjs/core";
import { SmartbinController } from "./smartbin.controller";
import { SmartbinService } from "./smartbin.service";
import { MachineTelemetryService } from "./machine-telemetry.service";
import { AccessTokenGuard } from "./auth/access-token.guard";
import { CardEntity } from "./entities/card.entity";
import { DepositEntity } from "./entities/deposit.entity";
import { MachineEntity } from "./entities/machine.entity";
import { NotificationEntity } from "./entities/notification.entity";
import { PointLedgerEntity } from "./entities/point-ledger.entity";
import { RateEntity } from "./entities/rate.entity";
import { RefreshSessionEntity } from "./entities/refresh-session.entity";
import { UserEntity } from "./entities/user.entity";

const entities = [
  UserEntity,
  CardEntity,
  DepositEntity,
  PointLedgerEntity,
  MachineEntity,
  RateEntity,
  NotificationEntity,
  RefreshSessionEntity,
];

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: (config: Record<string, unknown>) => {
        if (
          typeof config.NIK_HMAC_SECRET !== "string" ||
          config.NIK_HMAC_SECRET.length < 32
        ) {
          throw new Error("NIK_HMAC_SECRET must contain at least 32 characters.");
        }
        return config;
      },
    }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const synchronize = config.get("DB_SYNCHRONIZE") === "true";
        if (config.get("NODE_ENV") === "production" && synchronize) {
          throw new Error("DB_SYNCHRONIZE must be false in production.");
        }
        return {
          type: "mysql" as const,
          host: config.getOrThrow<string>("DB_HOST"),
          port: Number(config.get("DB_PORT", 3306)),
          username: config.getOrThrow<string>("DB_USERNAME"),
          password: config.getOrThrow<string>("DB_PASSWORD"),
          database: config.getOrThrow<string>("DB_DATABASE"),
          entities,
          synchronize,
          timezone: "Z",
          charset: "utf8mb4",
        };
      },
    }),
    TypeOrmModule.forFeature(entities),
    JwtModule.registerAsync({
      global: true,
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>("JWT_ACCESS_SECRET"),
        signOptions: { expiresIn: "15m" },
      }),
    }),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 100 }]),
  ],
  controllers: [SmartbinController],
  providers: [
    SmartbinService,
    MachineTelemetryService,
    AccessTokenGuard,
    { provide: APP_GUARD, useClass: ThrottlerGuard },
  ],
})
export class AppModule {}
