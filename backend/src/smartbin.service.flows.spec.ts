import { UnauthorizedException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { JwtService } from "@nestjs/jwt";
import { DataSource, In, LessThan, Repository } from "typeorm";
import { CaptureStorageService } from "./capture-storage.service";
import { CardEntity } from "./entities/card.entity";
import { DepositEntity } from "./entities/deposit.entity";
import { MachineEntity } from "./entities/machine.entity";
import { NotificationEntity } from "./entities/notification.entity";
import { PointLedgerEntity } from "./entities/point-ledger.entity";
import { RateEntity } from "./entities/rate.entity";
import { RefreshSessionEntity } from "./entities/refresh-session.entity";
import { UserEntity } from "./entities/user.entity";
import { SmartbinController } from "./smartbin.controller";
import { SmartbinService } from "./smartbin.service";

type Mocks = Partial<{
  users: object;
  cards: object;
  deposits: object;
  ledger: object;
  machines: object;
  rates: object;
  notifications: object;
  sessions: object;
  dataSource: object;
  captures: object;
}>;

function build(mocks: Mocks = {}): SmartbinService {
  const config = new ConfigService();
  jest.spyOn(config, "get").mockImplementation((_key, fallback) => fallback);
  jest.spyOn(config, "getOrThrow").mockReturnValue("test-secret" as never);
  return new SmartbinService(
    (mocks.users ?? {}) as Repository<UserEntity>,
    (mocks.cards ?? {}) as Repository<CardEntity>,
    (mocks.deposits ?? {}) as Repository<DepositEntity>,
    (mocks.ledger ?? {}) as Repository<PointLedgerEntity>,
    (mocks.machines ?? {}) as Repository<MachineEntity>,
    (mocks.rates ?? {}) as Repository<RateEntity>,
    (mocks.notifications ?? {}) as Repository<NotificationEntity>,
    (mocks.sessions ?? {}) as Repository<RefreshSessionEntity>,
    (mocks.dataSource ?? {}) as DataSource,
    {} as JwtService,
    config,
    (mocks.captures ?? {}) as CaptureStorageService,
  );
}

/** Query builder palsu yang mengembalikan nilai tetap dan merekam pemanggilan. */
function queryBuilder(result: { one?: unknown; many?: unknown[] }) {
  const qb: Record<string, jest.Mock> = {};
  for (const method of ["select", "addSelect", "where", "andWhere", "groupBy"])
    qb[method] = jest.fn().mockReturnValue(qb);
  qb.getRawOne = jest.fn().mockResolvedValue(result.one);
  qb.getRawMany = jest.fn().mockResolvedValue(result.many ?? []);
  return qb;
}

describe("SmartbinController", () => {
  it("meneruskan id setoran lalu id pengguna ke service", async () => {
    const service = { deposit: jest.fn().mockResolvedValue({}) };
    const controller = new SmartbinController(
      service as unknown as SmartbinService,
      {} as never,
      {} as never,
    );

    await controller.deposit(
      { user: { sub: "user-1", role: "user" } } as never,
      "tx-1",
    );

    expect(service.deposit).toHaveBeenCalledWith("tx-1", "user-1");
  });
});

describe("SmartbinService.refresh", () => {
  it("menolak perpanjangan sesi untuk akun yang dinonaktifkan", async () => {
    const sessions = {
      findOne: jest.fn().mockResolvedValue({
        id: "s1",
        userId: "u1",
        revokedAt: null,
        expiresAt: new Date(Date.now() + 60_000),
      }),
      update: jest.fn(),
    };
    const users = {
      findOneBy: jest.fn().mockResolvedValue({ id: "u1", active: false }),
    };
    const service = build({ sessions, users });

    await expect(service.refresh("a".repeat(48))).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(sessions.update).not.toHaveBeenCalled();
  });
});

describe("SmartbinService.linkCard", () => {
  function setup(held: Array<Partial<DepositEntity>>) {
    const savedLedger: unknown[] = [];
    const deposits = {
      find: jest.fn().mockResolvedValue(held),
      update: jest.fn().mockResolvedValue({ affected: held.length }),
    };
    const ledger = {
      create: jest.fn((rows) => rows),
      save: jest.fn(async (rows) => savedLedger.push(rows)),
    };
    const notifications = {
      create: jest.fn((row) => row),
      save: jest.fn(),
    };
    const cardsInTx = {
      findOneBy: jest.fn().mockResolvedValue(null),
      create: jest.fn((row) => row),
      save: jest.fn(),
      remove: jest.fn(),
    };
    const manager = {
      getRepository: (entity: unknown) =>
        entity === CardEntity
          ? cardsInTx
          : entity === DepositEntity
            ? deposits
            : entity === PointLedgerEntity
              ? ledger
              : notifications,
    };
    const service = build({
      cards: { findOneBy: jest.fn().mockResolvedValue(null) },
      dataSource: {
        transaction: jest.fn(async (callback) => callback(manager)),
      },
    });
    return { service, deposits, ledger, notifications, savedLedger };
  }

  it("mengkreditkan semua setoran tertahan dengan satu update, satu insert ledger, dan satu notifikasi", async () => {
    const { service, deposits, ledger, notifications } = setup([
      { id: "d1", transactionId: "t1", points: 40 },
      { id: "d2", transactionId: "t2", points: 80 },
    ]);

    await expect(service.linkCard("user-1", "04A1B2C3")).resolves.toEqual({
      linked: true,
      creditedPoints: 120,
      creditedDeposits: 2,
    });

    expect(deposits.update).toHaveBeenCalledTimes(1);
    expect(deposits.update).toHaveBeenCalledWith(
      { id: In(["d1", "d2"]) },
      { userId: "user-1", status: "CREDITED" },
    );
    expect(ledger.save).toHaveBeenCalledTimes(1);
    expect(ledger.create).toHaveBeenCalledWith([
      { userId: "user-1", delta: 40, reason: "DEPOSIT", referenceId: "t1" },
      { userId: "user-1", delta: 80, reason: "DEPOSIT", referenceId: "t2" },
    ]);
    expect(notifications.save).toHaveBeenCalledTimes(1);
    expect(notifications.create).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: "user-1",
        kind: "deposit",
        referenceId: null,
        body: expect.stringContaining("120 poin"),
      }),
    );
  });

  it("tidak menulis ledger maupun notifikasi bila tidak ada setoran tertahan", async () => {
    const { service, deposits, ledger, notifications } = setup([]);

    await expect(service.linkCard("user-1", "04A1B2C3")).resolves.toEqual({
      linked: true,
      creditedPoints: 0,
      creditedDeposits: 0,
    });

    expect(deposits.update).not.toHaveBeenCalled();
    expect(ledger.save).not.toHaveBeenCalled();
    expect(notifications.save).not.toHaveBeenCalled();
  });
});

describe("SmartbinService.pointsSummary", () => {
  it("menghitung saldo dan ringkasan bulanan di database, bukan di memori", async () => {
    const ledgerQb = queryBuilder({ one: { balance: "1450" } });
    const heldQb = queryBuilder({ one: { points: "120", count: "2" } });
    const monthQb = queryBuilder({
      many: [
        { type: "ORGANIK", count: "3", weightG: "1500", points: "60" },
        { type: "RESIDU", count: "1", weightG: "500", points: "0" },
      ],
    });
    const deposits = {
      createQueryBuilder: jest
        .fn()
        .mockReturnValueOnce(heldQb)
        .mockReturnValueOnce(monthQb),
    };
    const ledger = { createQueryBuilder: jest.fn().mockReturnValue(ledgerQb) };
    const service = build({ deposits, ledger });

    const summary = (await service.pointsSummary("user-1")) as Record<
      string,
      unknown
    >;

    expect(summary).toMatchObject({
      balance: 1450,
      heldPoints: 120,
      heldDeposits: 2,
      organicG: 1500,
      organicCount: 3,
      organicPoints: 60,
      inorganicG: 0,
      inorganicCount: 0,
      inorganicPoints: 0,
      residuG: 500,
      residuCount: 1,
    });
    expect(monthQb.groupBy).toHaveBeenCalledWith("deposit.type");
  });
});

describe("SmartbinService.authenticateMqttCard", () => {
  it("mengambil saldo lewat SUM ledger", async () => {
    const ledgerQb = queryBuilder({ one: { balance: "250" } });
    const service = build({
      cards: { findOneBy: jest.fn().mockResolvedValue({ userId: "u1" }) },
      users: {
        findOneBy: jest
          .fn()
          .mockResolvedValue({ id: "u1", name: "Rama", active: true }),
      },
      ledger: { createQueryBuilder: jest.fn().mockReturnValue(ledgerQb) },
    });

    await expect(service.authenticateMqttCard("a".repeat(64))).resolves.toEqual(
      { found: true, name: "Rama", balance: 250 },
    );
  });
});

describe("SmartbinService.rates cache", () => {
  it("membaca tarif sekali lalu memakai cache sampai tarif diperbarui", async () => {
    const row = {
      id: 1,
      organikPerKg: 40,
      anorganikPerKg: 100,
      updatedAt: new Date("2026-11-01T00:00:00.000Z"),
    };
    const rates = {
      findOneBy: jest.fn().mockResolvedValue(row),
      save: jest.fn().mockResolvedValue(row),
    };
    const service = build({ rates });

    await service.rates();
    await service.rates();
    expect(rates.findOneBy).toHaveBeenCalledTimes(1);

    await service.updateRates({ organikPerKg: 50, anorganikPerKg: 120 });
    await service.rates();
    expect(rates.findOneBy).toHaveBeenCalledTimes(3);
  });
});

describe("SmartbinService sessions", () => {
  it("updateAdminUser mencabut sesi aktif saat akun dinonaktifkan", async () => {
    const user = {
      id: "u1",
      name: "A",
      email: "a@example.com",
      role: "user",
      active: true,
    };
    const sessions = { update: jest.fn().mockResolvedValue({ affected: 1 }) };
    const service = build({
      users: {
        findOneBy: jest.fn().mockResolvedValue(user),
        save: jest.fn(),
      },
      sessions,
    });

    await service.updateAdminUser("u1", { active: false });

    expect(sessions.update).toHaveBeenCalledWith(
      { userId: "u1", revokedAt: expect.anything() },
      { revokedAt: expect.any(Date) },
    );
  });

  it("purgeSessions menghapus sesi kedaluwarsa dan sesi lama yang dicabut", async () => {
    const sessions = { delete: jest.fn().mockResolvedValue({ affected: 0 }) };
    const service = build({ sessions });

    await service.purgeSessions();

    expect(sessions.delete).toHaveBeenCalledTimes(2);
    expect(sessions.delete).toHaveBeenNthCalledWith(1, {
      expiresAt: expect.objectContaining({ _type: "lessThan" }),
    });
    expect(sessions.delete).toHaveBeenNthCalledWith(2, {
      revokedAt: expect.objectContaining({ _type: "lessThan" }),
    });
    expect(LessThan(new Date())).toHaveProperty("_type", "lessThan");
  });

  it("purgeSessions tidak melempar error saat database gagal", async () => {
    const sessions = { delete: jest.fn().mockRejectedValue(new Error("down")) };
    const service = build({ sessions });

    await expect(service.purgeSessions()).resolves.toBeUndefined();
  });
});

describe("SmartbinService photo flag", () => {
  const deposit = (hasPhoto: boolean | null) =>
    ({
      id: "d1",
      transactionId: "5f0c3a4e-8b1d-4f7e-9a2c-1b2c3d4e5f60",
      machineId: "m1",
      machine: { name: "Unit" },
      type: "ORGANIK",
      itemLabel: "",
      weightG: 1000,
      points: 40,
      ratePerKg: 40,
      deviceTime: new Date("2026-11-01T00:00:00.000Z"),
      receivedAt: new Date("2026-11-01T00:00:01.000Z"),
      status: "CREDITED",
      hasPhoto,
    }) as DepositEntity;

  it("tidak memeriksa filesystem bila penanda foto sudah ada", async () => {
    const captures = { exists: jest.fn() };
    const depositsRepo = { update: jest.fn() };
    const service = build({ captures, deposits: depositsRepo });

    const result = (await service["publicDeposit"](deposit(true))) as {
      photoUrl: string | null;
    };

    expect(result.photoUrl).toContain("captures/");
    expect(captures.exists).not.toHaveBeenCalled();
    expect(depositsRepo.update).not.toHaveBeenCalled();
  });

  it("memeriksa filesystem sekali untuk baris lama lalu menyimpan hasilnya", async () => {
    const captures = { exists: jest.fn().mockResolvedValue(false) };
    const depositsRepo = { update: jest.fn() };
    const service = build({ captures, deposits: depositsRepo });

    const result = (await service["publicDeposit"](deposit(null))) as {
      photoUrl: string | null;
    };

    expect(result.photoUrl).toBeNull();
    expect(captures.exists).toHaveBeenCalledTimes(1);
    expect(depositsRepo.update).toHaveBeenCalledWith(
      { id: "d1" },
      { hasPhoto: false },
    );
  });
});
