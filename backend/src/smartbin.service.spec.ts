import { ConfigService } from "@nestjs/config";
import { JwtService } from "@nestjs/jwt";
import { DataSource, Repository } from "typeorm";
import { CardEntity } from "./entities/card.entity";
import { DepositEntity } from "./entities/deposit.entity";
import { MachineEntity } from "./entities/machine.entity";
import { NotificationEntity } from "./entities/notification.entity";
import { PointLedgerEntity } from "./entities/point-ledger.entity";
import { RateEntity } from "./entities/rate.entity";
import { RefreshSessionEntity } from "./entities/refresh-session.entity";
import { UserEntity } from "./entities/user.entity";
import { CaptureStorageService } from "./capture-storage.service";
import { SmartbinService } from "./smartbin.service";

describe("SmartbinService token response", () => {
  it("returns all admin deposits, including unlinked cards and residu", async () => {
    const deposits = {
      find: jest.fn().mockResolvedValue([
        {
          transactionId: "unlinked-test",
          userId: null,
          machine: { name: "SmartBIN Unit #01" },
          machineId: "machine-1",
          type: "RESIDU",
          weightG: 500,
          points: 0,
          deviceTime: new Date("2026-10-31T12:00:00.000Z"),
        },
      ]),
    };
    const service = new SmartbinService(
      {} as Repository<UserEntity>,
      {} as Repository<CardEntity>,
      deposits as unknown as Repository<DepositEntity>,
      {} as Repository<PointLedgerEntity>,
      {} as Repository<MachineEntity>,
      {} as Repository<RateEntity>,
      {} as Repository<NotificationEntity>,
      {} as Repository<RefreshSessionEntity>,
      {} as DataSource,
      {} as JwtService,
      new ConfigService(),
      {} as CaptureStorageService,
    );

    await expect(service.adminHistory()).resolves.toEqual([
      {
        id: "unlinked-test",
        userId: "-",
        machine: "SmartBIN Unit #01",
        type: "Residu",
        weightKg: 0.5,
        points: 0,
        time: "2026-10-31T12:00:00.000Z",
      },
    ]);
    expect(deposits.find).toHaveBeenCalledWith({
      relations: { machine: true, user: true },
      order: { deviceTime: "DESC" },
      take: 1000,
    });
  });

  it("includes the linked card when login or refresh issues tokens", async () => {
    const linkedAt = new Date("2026-10-31T12:00:00.000Z");
    const card = {
      userId: "user-1",
      uidHash: "a".repeat(60) + "9abc",
      linkedAt,
    } as CardEntity;
    const cards = {
      findOneBy: jest.fn().mockResolvedValue(card),
    };
    const sessions = {
      create: jest.fn((session) => session),
      save: jest.fn().mockResolvedValue(undefined),
    };
    const jwt = { signAsync: jest.fn().mockResolvedValue("access-token") };
    const config = new ConfigService();
    const configGet = jest.spyOn(config, "get").mockReturnValue(30);
    jest.spyOn(config, "getOrThrow").mockReturnValue("test-secret" as never);
    const service = new SmartbinService(
      {} as Repository<UserEntity>,
      cards as unknown as Repository<CardEntity>,
      {} as Repository<DepositEntity>,
      {} as Repository<PointLedgerEntity>,
      {} as Repository<MachineEntity>,
      {} as Repository<RateEntity>,
      {} as Repository<NotificationEntity>,
      sessions as unknown as Repository<RefreshSessionEntity>,
      {} as DataSource,
      jwt as unknown as JwtService,
      config,
      {} as CaptureStorageService,
    );
    const user = {
      id: "user-1",
      name: "Test User",
      email: "test@example.com",
      role: "user",
    } as UserEntity;

    const result = (await service["issueTokens"](user)) as {
      user: { card: { linkedAt: string; uidHashSuffix: string } | null };
    };

    expect(cards.findOneBy).toHaveBeenCalledWith({ userId: "user-1" });
    expect(result.user.card).toEqual({
      linkedAt: linkedAt.toISOString(),
      uidHashSuffix: "9abc",
    });
    expect(configGet).toHaveBeenCalledWith("JWT_REFRESH_DAYS", 30);
  });
});
