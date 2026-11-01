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

function build(
  mocks: Mocks = {},
  env: Record<string, string> = {},
): SmartbinService {
  const config = new ConfigService();
  jest
    .spyOn(config, "get")
    .mockImplementation(
      (key: string, fallback?: unknown) => env[key] ?? fallback,
    );
  jest
    .spyOn(config, "getOrThrow")
    .mockImplementation((key: string) => (env[key] ?? "test-secret") as never);
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
  for (const method of [
    "select",
    "addSelect",
    "where",
    "andWhere",
    "groupBy",
    "leftJoinAndSelect",
    "orderBy",
    "addOrderBy",
    "take",
  ])
    qb[method] = jest.fn().mockReturnValue(qb);
  qb.getRawOne = jest.fn().mockResolvedValue(result.one);
  qb.getRawMany = jest.fn().mockResolvedValue(result.many ?? []);
  qb.getMany = jest.fn().mockResolvedValue(result.many ?? []);
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

describe("SmartbinService machine keys", () => {
  const env = {
    MACHINE_API_KEY: "shared-key",
    MACHINE_API_KEYS: "esp1=key-one, esp2=key-two",
  };
  const service = () => build({}, env);

  it("perangkat dengan kunci sendiri hanya menerima kunci itu", () => {
    expect(() => service().assertMachineKey("key-one", "esp1")).not.toThrow();
    expect(() => service().assertMachineKey("shared-key", "esp1")).toThrow(
      UnauthorizedException,
    );
    expect(() => service().assertMachineKey("key-two", "esp1")).toThrow(
      UnauthorizedException,
    );
  });

  it("perangkat tanpa kunci khusus tetap memakai kunci bersama", () => {
    expect(() =>
      service().assertMachineKey("shared-key", "esp3"),
    ).not.toThrow();
    expect(() => service().assertMachineKey("key-one", "esp3")).toThrow(
      UnauthorizedException,
    );
  });

  it("gerbang awal tanpa deviceId menerima kunci bersama atau kunci perangkat mana pun", () => {
    expect(() => service().assertMachineKey("shared-key")).not.toThrow();
    expect(() => service().assertMachineKey("key-two")).not.toThrow();
    expect(() => service().assertMachineKey("salah")).toThrow(
      UnauthorizedException,
    );
    expect(() => service().assertMachineKey(undefined)).toThrow(
      UnauthorizedException,
    );
  });

  it("tanpa MACHINE_API_KEYS perilaku lama tidak berubah", () => {
    const legacy = build({}, { MACHINE_API_KEY: "shared-key" });
    expect(() => legacy.assertMachineKey("shared-key", "esp1")).not.toThrow();
    expect(() => legacy.assertMachineKey("key-one", "esp1")).toThrow(
      UnauthorizedException,
    );
  });
});

describe("SmartbinService.adminHistory paging", () => {
  const row = (id: string, time: string) => ({
    id,
    transactionId: `tx-${id}`,
    userId: null,
    user: null,
    machine: { name: "Unit" },
    machineId: "m1",
    type: "ORGANIK",
    weightG: 1000,
    points: 40,
    deviceTime: new Date(time),
  });

  it("mengembalikan nextCursor yang dapat dipakai untuk halaman berikutnya", async () => {
    const qb = queryBuilder({
      many: [
        row("c", "2026-11-01T03:00:00.000Z"),
        row("b", "2026-11-01T02:00:00.000Z"),
        row("a", "2026-11-01T01:00:00.000Z"),
      ],
    });
    const service = build({ deposits: { createQueryBuilder: () => qb } });

    const page = (await service.adminHistory({
      limit: 2,
      paged: true,
    })) as { data: Array<{ id: string }>; nextCursor: string | null };

    expect(page.data.map((item) => item.id)).toEqual(["tx-c", "tx-b"]);
    expect(qb.take).toHaveBeenCalledWith(3);
    expect(
      JSON.parse(Buffer.from(page.nextCursor!, "base64url").toString()),
    ).toEqual({
      deviceTime: "2026-11-01T02:00:00.000Z",
      id: "b",
    });
  });

  it("nextCursor null pada halaman terakhir dan cursor memfilter baris yang sudah terbaca", async () => {
    const qb = queryBuilder({ many: [row("a", "2026-11-01T01:00:00.000Z")] });
    const service = build({ deposits: { createQueryBuilder: () => qb } });
    const cursor = Buffer.from(
      JSON.stringify({ deviceTime: "2026-11-01T02:00:00.000Z", id: "b" }),
    ).toString("base64url");

    const page = (await service.adminHistory({
      limit: 2,
      paged: true,
      cursor,
    })) as { nextCursor: string | null };

    expect(page.nextCursor).toBeNull();
    expect(qb.andWhere).toHaveBeenCalledWith(
      expect.stringContaining("deposit.id < :cursorId"),
      { cursorTime: new Date("2026-11-01T02:00:00.000Z"), cursorId: "b" },
    );
  });
});

describe("SmartbinService.adminDailyWeights", () => {
  afterEach(() => jest.useRealTimers());

  it("mengisi hari tanpa setoran dengan 0 dan memakai batas awal hari WIB", async () => {
    jest.useFakeTimers().setSystemTime(new Date("2026-11-01T20:00:00.000Z"));
    const qb = queryBuilder({
      many: [{ bucket: "2026-11-01", weightG: "1500" }],
    });
    const service = build({ deposits: { createQueryBuilder: () => qb } });

    await expect(service.adminDailyWeights(3)).resolves.toEqual([
      { date: "2026-10-31", weightKg: 0 },
      { date: "2026-11-01", weightKg: 1.5 },
      { date: "2026-11-02", weightKg: 0 },
    ]);
    expect(qb.where).toHaveBeenCalledWith("deposit.deviceTime >= :since", {
      since: new Date("2026-10-30T17:00:00.000Z"),
    });
  });
});

describe("SmartbinService.depositStats", () => {
  it("meringkas jumlah, berat, dan poin per jenis dari seluruh data", async () => {
    const qb = queryBuilder({
      many: [
        { type: "ORGANIK", count: "30", weightG: "12000", points: "480" },
        { type: "RESIDU", count: "2", weightG: "700", points: "0" },
      ],
    });
    const service = build({ deposits: { createQueryBuilder: () => qb } });

    await expect(service.depositStats("user-1", {})).resolves.toEqual({
      organik: { count: 30, weightG: 12000, points: 480 },
      anorganik: { count: 0, weightG: 0, points: 0 },
      residu: { count: 2, weightG: 700, points: 0 },
    });
  });
});
