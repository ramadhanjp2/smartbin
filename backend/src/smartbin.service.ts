import {
  ConflictException,
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { JwtService } from "@nestjs/jwt";
import { InjectRepository } from "@nestjs/typeorm";
import * as bcrypt from "bcryptjs";
import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import { DataSource, IsNull, MoreThan, Repository } from "typeorm";
import { CardEntity } from "./entities/card.entity";
import { DepositEntity } from "./entities/deposit.entity";
import { MachineEntity } from "./entities/machine.entity";
import { NotificationEntity } from "./entities/notification.entity";
import { PointLedgerEntity } from "./entities/point-ledger.entity";
import { RateEntity } from "./entities/rate.entity";
import { RefreshSessionEntity } from "./entities/refresh-session.entity";
import { UserEntity, UserRole } from "./entities/user.entity";
import { calculatePoints } from "./points";
import {
  DepositQueryDto,
  IngestDepositDto,
  LoginDto,
  MachineStatusDto,
  RegisterDto,
  UpdateMeDto,
  UpdateRatesDto,
  UpdateMachineDto,
} from "./dto";

@Injectable()
export class SmartbinService {
  private readonly failures = new Map<
    string,
    { count: number; until: number }
  >();

  constructor(
    @InjectRepository(UserEntity)
    private readonly users: Repository<UserEntity>,
    @InjectRepository(CardEntity)
    private readonly cards: Repository<CardEntity>,
    @InjectRepository(DepositEntity)
    private readonly depositsRepo: Repository<DepositEntity>,
    @InjectRepository(PointLedgerEntity)
    private readonly ledger: Repository<PointLedgerEntity>,
    @InjectRepository(MachineEntity)
    private readonly machinesRepo: Repository<MachineEntity>,
    @InjectRepository(RateEntity)
    private readonly ratesRepo: Repository<RateEntity>,
    @InjectRepository(NotificationEntity)
    private readonly notificationsRepo: Repository<NotificationEntity>,
    @InjectRepository(RefreshSessionEntity)
    private readonly sessions: Repository<RefreshSessionEntity>,
    private readonly dataSource: DataSource,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async register(dto: RegisterDto): Promise<unknown> {
    const nikHash = this.nikHash(dto.nik);
    const email = dto.email.trim().toLowerCase();
    const exists = await this.users.findOne({
      where: [{ nikHash }, { email }],
    });
    if (exists)
      throw new ConflictException({
        code: "ACCOUNT_EXISTS",
        message: "NIK atau email sudah terdaftar.",
      });
    const user = this.users.create({
      nikHash,
      email,
      name: dto.name.trim(),
      passwordHash: await bcrypt.hash(dto.password, 12),
      role: "user",
    });
    await this.users.save(user);
    return this.issueTokens(user);
  }

  async login(dto: LoginDto): Promise<unknown> {
    const rawIdentifier = dto.identifier.trim();
    const isEmail = rawIdentifier.includes("@");
    const isNik = /^\d{16}$/.test(rawIdentifier);
    const identifier = isEmail
      ? rawIdentifier.toLowerCase()
      : rawIdentifier.toUpperCase();
    const lookupIdentifier = isNik ? this.nikHash(rawIdentifier) : identifier;
    const failureKey = isNik ? lookupIdentifier : identifier;
    const storedAttempt = this.failures.get(failureKey);
    if (storedAttempt && storedAttempt.until > Date.now()) {
      throw new UnauthorizedException({
        code: "LOGIN_LOCKED",
        message: "Terlalu banyak percobaan. Coba lagi beberapa menit.",
      });
    }
    const attempt =
      storedAttempt?.until && storedAttempt.until <= Date.now()
        ? undefined
        : storedAttempt;
    if (storedAttempt?.until && storedAttempt.until <= Date.now())
      this.failures.delete(failureKey);

    const user = await this.users
      .createQueryBuilder("user")
      .addSelect("user.passwordHash")
      .where("user.email = :identifier OR user.nikHash = :nikHash", {
        identifier,
        nikHash: isNik ? lookupIdentifier : "",
      })
      .getOne();
    const valid = user
      ? await bcrypt.compare(dto.password, user.passwordHash)
      : false;
    if (!user || !valid) {
      const count = (attempt?.count ?? 0) + 1;
      const max = Number(this.config.get("LOGIN_MAX_ATTEMPTS", 5));
      this.failures.set(failureKey, {
        count,
        until: count >= max ? Date.now() + 5 * 60_000 : 0,
      });
      throw new UnauthorizedException({
        code: "INVALID_CREDENTIALS",
        message: "NIK/email atau kata sandi salah.",
      });
    }
    this.failures.delete(failureKey);
    return this.issueTokens(user);
  }

  async refresh(refreshToken: string): Promise<unknown> {
    const tokenHash = this.hashToken(refreshToken);
    const session = await this.sessions.findOne({ where: { tokenHash } });
    if (!session || session.revokedAt || session.expiresAt <= new Date()) {
      throw new UnauthorizedException({
        code: "INVALID_REFRESH_TOKEN",
        message: "Sesi berakhir. Silakan masuk kembali.",
      });
    }
    const user = await this.users.findOneBy({ id: session.userId });
    if (!user)
      throw new UnauthorizedException({
        code: "INVALID_REFRESH_TOKEN",
        message: "Sesi berakhir. Silakan masuk kembali.",
      });
    const revoked = await this.sessions.update(
      { id: session.id, revokedAt: IsNull(), expiresAt: MoreThan(new Date()) },
      { revokedAt: new Date() },
    );
    if (!revoked.affected) {
      throw new UnauthorizedException({
        code: "INVALID_REFRESH_TOKEN",
        message: "Sesi berakhir. Silakan masuk kembali.",
      });
    }
    return this.issueTokens(user);
  }

  async logout(refreshToken: string): Promise<{ success: true }> {
    await this.sessions.update(
      { tokenHash: this.hashToken(refreshToken) },
      { revokedAt: new Date() },
    );
    return { success: true };
  }

  async me(userId: string): Promise<unknown> {
    const user = await this.users.findOne({
      where: { id: userId },
      relations: { card: true },
    });
    if (!user)
      throw new NotFoundException({
        code: "USER_NOT_FOUND",
        message: "Akun tidak ditemukan.",
      });
    return this.publicUser(user);
  }

  async updateMe(userId: string, dto: UpdateMeDto): Promise<unknown> {
    if (dto.newPassword && !dto.oldPassword) {
      throw new ConflictException({
        code: "OLD_PASSWORD_REQUIRED",
        message: "Kata sandi lama wajib diisi.",
      });
    }
    const user = await this.users
      .createQueryBuilder("user")
      .addSelect("user.passwordHash")
      .where("user.id = :userId", { userId })
      .getOne();
    if (!user)
      throw new NotFoundException({
        code: "USER_NOT_FOUND",
        message: "Akun tidak ditemukan.",
      });
    if (dto.newPassword) {
      if (!(await bcrypt.compare(dto.oldPassword!, user.passwordHash))) {
        throw new UnauthorizedException({
          code: "INVALID_PASSWORD",
          message: "Kata sandi lama tidak sesuai.",
        });
      }
      user.passwordHash = await bcrypt.hash(dto.newPassword, 12);
      await this.sessions.update({ userId }, { revokedAt: new Date() });
    }
    if (dto.name) user.name = dto.name.trim();
    await this.users.save(user);
    return this.me(userId);
  }

  async linkCard(userId: string, uid: string): Promise<unknown> {
    const uidHash = this.cardHash(uid);
    const existing = await this.cards.findOneBy({ uidHash });
    if (existing && existing.userId !== userId) {
      throw new ConflictException({
        code: "CARD_ALREADY_LINKED",
        message: "KTP sudah ditautkan ke akun lain.",
      });
    }
    let creditedPoints = 0;
    let creditedDeposits = 0;
    await this.dataSource.transaction(async (manager) => {
      const cards = manager.getRepository(CardEntity);
      const current = await cards.findOneBy({ userId });
      if (current?.uidHash === uidHash) return;
      if (current) await cards.remove(current);
      await cards.save(cards.create({ userId, uidHash }));

      const held = await manager.getRepository(DepositEntity).find({
        where: { uidHash, status: "HELD" },
        order: { receivedAt: "ASC" },
      });
      creditedDeposits = held.length;
      for (const deposit of held) {
        deposit.userId = userId;
        deposit.status = "CREDITED";
        await manager.getRepository(DepositEntity).save(deposit);
        creditedPoints += deposit.points;
        await manager.getRepository(PointLedgerEntity).save(
          manager.getRepository(PointLedgerEntity).create({
            userId,
            delta: deposit.points,
            reason: "DEPOSIT",
            referenceId: deposit.transactionId,
          }),
        );
      }
    });
    return { linked: true, creditedPoints, creditedDeposits };
  }

  async unlinkCard(
    userId: string,
    password: string,
  ): Promise<{ success: true }> {
    const user = await this.users
      .createQueryBuilder("user")
      .addSelect("user.passwordHash")
      .where("user.id = :userId", { userId })
      .getOne();
    if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
      throw new UnauthorizedException({
        code: "INVALID_PASSWORD",
        message: "Kata sandi tidak sesuai.",
      });
    }
    await this.cards.delete({ userId });
    return { success: true };
  }

  async pointsSummary(userId: string): Promise<unknown> {
    const [entries, held] = await Promise.all([
      this.ledger.find({ where: { userId } }),
      this.depositsRepo.find({ where: { userId, status: "HELD" } }),
    ]);
    const start = new Date();
    start.setUTCDate(1);
    start.setUTCHours(0, 0, 0, 0);
    const monthDeposits = await this.depositsRepo
      .createQueryBuilder("deposit")
      .where("deposit.userId = :userId", { userId })
      .andWhere("deposit.status = :status", { status: "CREDITED" })
      .andWhere("deposit.deviceTime >= :start", { start })
      .getMany();
    const byType = (type: "ORGANIK" | "ANORGANIK") =>
      monthDeposits.filter((deposit) => deposit.type === type);
    return {
      balance: entries.reduce((sum, entry) => sum + entry.delta, 0),
      heldPoints: held.reduce((sum, deposit) => sum + deposit.points, 0),
      heldDeposits: held.length,
      month: start.toISOString(),
      organicG: byType("ORGANIK").reduce(
        (sum, deposit) => sum + deposit.weightG,
        0,
      ),
      inorganicG: byType("ANORGANIK").reduce(
        (sum, deposit) => sum + deposit.weightG,
        0,
      ),
      organicCount: byType("ORGANIK").length,
      inorganicCount: byType("ANORGANIK").length,
      organicPoints: byType("ORGANIK").reduce(
        (sum, deposit) => sum + deposit.points,
        0,
      ),
      inorganicPoints: byType("ANORGANIK").reduce(
        (sum, deposit) => sum + deposit.points,
        0,
      ),
      updatedAt: new Date().toISOString(),
    };
  }

  async deposits(userId: string, query: DepositQueryDto): Promise<unknown> {
    const builder = this.depositsRepo
      .createQueryBuilder("deposit")
      .leftJoinAndSelect("deposit.machine", "machine")
      .where("deposit.userId = :userId", { userId })
      .orderBy("deposit.deviceTime", "DESC")
      .addOrderBy("deposit.id", "DESC")
      .take(query.limit + 1);
    if (query.type)
      builder.andWhere("deposit.type = :type", { type: query.type });
    if (query.from)
      builder.andWhere("deposit.deviceTime >= :from", {
        from: new Date(query.from),
      });
    if (query.to)
      builder.andWhere("deposit.deviceTime <= :to", { to: new Date(query.to) });
    if (query.cursor) {
      const cursor = this.decodeCursor(query.cursor);
      builder.andWhere(
        "(deposit.deviceTime < :cursorTime OR (deposit.deviceTime = :cursorTime AND deposit.id < :cursorId))",
        { cursorTime: cursor.deviceTime, cursorId: cursor.id },
      );
    }
    const rows = await builder.getMany();
    const hasMore = rows.length > query.limit;
    const data = rows.slice(0, query.limit);
    return {
      data: data.map((deposit) => this.publicDeposit(deposit)),
      nextCursor: hasMore
        ? Buffer.from(
            JSON.stringify({
              deviceTime: data[data.length - 1].deviceTime.toISOString(),
              id: data[data.length - 1].id,
            }),
          ).toString("base64url")
        : null,
    };
  }

  async deposit(id: string, userId: string): Promise<unknown> {
    const deposit = await this.depositsRepo.findOne({
      where: [
        { id, userId },
        { transactionId: id, userId },
      ],
      relations: { machine: true },
    });
    if (!deposit)
      throw new NotFoundException({
        code: "DEPOSIT_NOT_FOUND",
        message: "Setoran tidak ditemukan.",
      });
    return this.publicDeposit(deposit);
  }

  async rates(): Promise<unknown> {
    const row = await this.getRates();
    return {
      organikPerKg: row.organikPerKg,
      anorganikPerKg: row.anorganikPerKg,
      updatedAt: row.updatedAt.toISOString(),
    };
  }

  async updateRates(dto: UpdateRatesDto): Promise<unknown> {
    const repo = this.ratesRepo;
    let row = await repo.findOneBy({ id: 1 });
    if (!row) row = repo.create({ id: 1 });
    row.organikPerKg = dto.organikPerKg;
    row.anorganikPerKg = dto.anorganikPerKg;
    await repo.save(row);
    return this.rates();
  }

  async adminUsers(): Promise<unknown> {
    const rows = await this.users.find({ order: { createdAt: "DESC" } });
    return rows.map((user) => ({
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      active: true,
    }));
  }

  async adminHistory(): Promise<unknown> {
    const rows = await this.depositsRepo.find({
      relations: { machine: true, user: true },
      order: { deviceTime: "DESC" },
      take: 1000,
    });
    return rows.map((deposit) => ({
      id: deposit.transactionId,
      userId: deposit.userId ?? "-",
      machine: deposit.machine?.name ?? deposit.machineId,
      type: deposit.type === "ORGANIK" ? "Organik" : "Anorganik",
      weightKg: Number((deposit.weightG / 1000).toFixed(3)),
      points: deposit.points,
      time: deposit.deviceTime.toISOString(),
    }));
  }

  async updateMachine(id: string, dto: UpdateMachineDto): Promise<unknown> {
    const machine = await this.machinesRepo.findOneBy({ id });
    if (!machine)
      throw new NotFoundException({
        code: "MACHINE_NOT_FOUND",
        message: "Mesin tidak ditemukan.",
      });
    if (dto.name !== undefined) machine.name = dto.name;
    if (dto.location !== undefined) machine.location = dto.location;
    await this.machinesRepo.save(machine);
    return this.machines();
  }

  async machines(): Promise<unknown> {
    const rows = await this.machinesRepo.find({ order: { name: "ASC" } });
    return rows.map((machine) => ({
      id: machine.id,
      code: machine.code,
      name: machine.name,
      location: machine.location,
      status: machine.status,
      lastSeen: machine.lastSeen?.toISOString() ?? null,
      organicFill: machine.organicFill,
      inorganicFill: machine.inorganicFill,
    }));
  }

  async resetMachine(id: string): Promise<unknown> {
    const machine = await this.machinesRepo.findOneBy({ id });
    if (!machine)
      throw new NotFoundException({
        code: "MACHINE_NOT_FOUND",
        message: "Mesin tidak ditemukan.",
      });
    machine.status = "SIAP";
    await this.machinesRepo.save(machine);
    return { id: machine.id, status: machine.status };
  }

  async ingestDeposit(
    machineId: string,
    machineKey: string | undefined,
    dto: IngestDepositDto,
  ): Promise<unknown> {
    this.assertMachineKey(machineKey);
    const machine = await this.machinesRepo.findOneBy({ id: machineId });
    if (!machine)
      throw new NotFoundException({
        code: "MACHINE_NOT_FOUND",
        message: "Mesin tidak ditemukan.",
      });
    const duplicate = await this.depositsRepo.findOneBy({
      transactionId: dto.transactionId,
    });
    if (duplicate)
      return { transactionId: duplicate.transactionId, duplicate: true };

    const uidHash = this.cardHash(dto.uid);
    const card = await this.cards.findOneBy({ uidHash });
    const rates = await this.getRates();
    const rate =
      dto.type === "ORGANIK" ? rates.organikPerKg : rates.anorganikPerKg;
    const points = calculatePoints(dto.weightG, rate);
    const status = card ? "CREDITED" : "HELD";
    try {
      const deposit = await this.dataSource.transaction(async (manager) => {
        const saved = await manager.getRepository(DepositEntity).save(
          manager.getRepository(DepositEntity).create({
            transactionId: dto.transactionId,
            machineId,
            userId: card?.userId ?? null,
            uidHash,
            type: dto.type,
            itemLabel: dto.itemLabel,
            weightG: dto.weightG,
            points,
            ratePerKg: rate,
            deviceTime: new Date(dto.deviceTime),
            status,
          }),
        );
        if (card) {
          await manager.getRepository(PointLedgerEntity).save(
            manager.getRepository(PointLedgerEntity).create({
              userId: card.userId,
              delta: points,
              reason: "DEPOSIT",
              referenceId: dto.transactionId,
            }),
          );
          await manager.getRepository(NotificationEntity).save(
            manager.getRepository(NotificationEntity).create({
              userId: card.userId,
              kind: "deposit",
              title: "Setoran berhasil tercatat",
              body: `Setoran ${dto.weightG} g ${dto.type.toLowerCase()} memperoleh ${points} poin.`,
              referenceId: dto.transactionId,
            }),
          );
        }
        machine.lastSeen = new Date();
        await manager.getRepository(MachineEntity).save(machine);
        return saved;
      });
      return {
        transactionId: deposit.transactionId,
        points: deposit.points,
        status: deposit.status,
        duplicate: false,
      };
    } catch (error) {
      if (this.isDuplicateKey(error)) {
        return { transactionId: dto.transactionId, duplicate: true };
      }
      throw error;
    }
  }

  async updateMachineStatus(
    machineId: string,
    machineKey: string | undefined,
    dto: MachineStatusDto,
  ): Promise<unknown> {
    this.assertMachineKey(machineKey);
    const machine = await this.machinesRepo.findOneBy({ id: machineId });
    if (!machine)
      throw new NotFoundException({
        code: "MACHINE_NOT_FOUND",
        message: "Mesin tidak ditemukan.",
      });
    machine.status = dto.status;
    if (dto.organicFill !== undefined) machine.organicFill = dto.organicFill;
    if (dto.inorganicFill !== undefined)
      machine.inorganicFill = dto.inorganicFill;
    machine.lastSeen = new Date();
    await this.machinesRepo.save(machine);
    return {
      id: machine.id,
      status: machine.status,
      lastSeen: machine.lastSeen.toISOString(),
    };
  }

  async notifications(userId: string): Promise<unknown> {
    const rows = await this.notificationsRepo.find({
      where: { userId },
      order: { createdAt: "DESC" },
      take: 100,
    });
    return rows.map((notification) => ({
      id: notification.id,
      kind: notification.kind,
      title: notification.title,
      body: notification.body,
      createdAt: notification.createdAt.toISOString(),
      read: notification.isRead,
      depositId: notification.referenceId,
    }));
  }

  async markNotificationRead(
    userId: string,
    id: string,
  ): Promise<{ success: true }> {
    const result = await this.notificationsRepo.update(
      { id, userId },
      { isRead: true },
    );
    if (!result.affected)
      throw new NotFoundException({
        code: "NOTIFICATION_NOT_FOUND",
        message: "Notifikasi tidak ditemukan.",
      });
    return { success: true };
  }

  async markAllNotificationsRead(userId: string): Promise<{ success: true }> {
    await this.notificationsRepo.update(
      { userId, isRead: false },
      { isRead: true },
    );
    return { success: true };
  }

  assertAdmin(role: UserRole): void {
    if (role !== "admin")
      throw new ForbiddenException({
        code: "FORBIDDEN",
        message: "Akses khusus admin.",
      });
  }

  private async issueTokens(user: UserEntity): Promise<unknown> {
    const accessToken = await this.jwt.signAsync({
      sub: user.id,
      role: user.role,
    });
    const refreshToken = randomBytes(48).toString("base64url");
    const days = Number(this.config.get("JWT_REFRESH_DAYS", 30));
    await this.sessions.save(
      this.sessions.create({
        userId: user.id,
        tokenHash: this.hashToken(refreshToken),
        expiresAt: new Date(Date.now() + days * 24 * 60 * 60_000),
        revokedAt: null,
      }),
    );
    return {
      accessToken,
      refreshToken,
      tokenType: "Bearer",
      expiresIn: 900,
      user: this.publicUser(user),
    };
  }

  private publicUser(user: UserEntity): unknown {
    return {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      card: user.card
        ? {
            linkedAt: user.card.linkedAt.toISOString(),
            uidHashSuffix: user.card.uidHash.slice(-4),
          }
        : null,
    };
  }

  private nikHash(nik: string): string {
    return createHmac(
      "sha256",
      this.config.getOrThrow<string>("NIK_HMAC_SECRET"),
    )
      .update(nik.trim())
      .digest("hex");
  }

  private publicDeposit(deposit: DepositEntity): unknown {
    return {
      transactionId: deposit.transactionId,
      machineId: deposit.machineId,
      machineName: deposit.machine?.name ?? "",
      type: deposit.type,
      itemLabel: deposit.itemLabel,
      weightG: deposit.weightG,
      points: deposit.points,
      ratePerKg: deposit.ratePerKg,
      deviceTime: deposit.deviceTime.toISOString(),
      receivedAt: deposit.receivedAt.toISOString(),
      status: deposit.status,
    };
  }

  private async getRates(): Promise<RateEntity> {
    let row = await this.ratesRepo.findOneBy({ id: 1 });
    if (!row) {
      row = this.ratesRepo.create({
        id: 1,
        organikPerKg: 40,
        anorganikPerKg: 100,
      });
      row = await this.ratesRepo.save(row);
    }
    return row;
  }

  private cardHash(uid: string): string {
    return createHmac(
      "sha256",
      this.config.getOrThrow<string>("CARD_HMAC_SECRET"),
    )
      .update(uid.trim().toUpperCase())
      .digest("hex");
  }

  private hashToken(token: string): string {
    return createHmac(
      "sha256",
      this.config.getOrThrow<string>("JWT_ACCESS_SECRET"),
    )
      .update(token)
      .digest("hex");
  }

  private assertMachineKey(provided: string | undefined): void {
    const expected = this.config.getOrThrow<string>("MACHINE_API_KEY");
    if (!provided)
      throw new UnauthorizedException({
        code: "INVALID_MACHINE_KEY",
        message: "Kunci mesin tidak valid.",
      });
    const actualBuffer = Buffer.from(provided);
    const expectedBuffer = Buffer.from(expected);
    if (
      actualBuffer.length !== expectedBuffer.length ||
      !timingSafeEqual(actualBuffer, expectedBuffer)
    ) {
      throw new UnauthorizedException({
        code: "INVALID_MACHINE_KEY",
        message: "Kunci mesin tidak valid.",
      });
    }
  }

  private isDuplicateKey(error: unknown): boolean {
    return (
      typeof error === "object" &&
      error !== null &&
      "code" in error &&
      error.code === "ER_DUP_ENTRY"
    );
  }

  private decodeCursor(value: string): { deviceTime: Date; id: string } {
    try {
      const decoded: unknown = JSON.parse(
        Buffer.from(value, "base64url").toString("utf8"),
      );
      if (
        typeof decoded !== "object" ||
        decoded === null ||
        !("deviceTime" in decoded) ||
        !("id" in decoded) ||
        typeof decoded.deviceTime !== "string" ||
        typeof decoded.id !== "string"
      ) {
        throw new Error("Invalid cursor shape");
      }
      const deviceTime = new Date(decoded.deviceTime);
      if (Number.isNaN(deviceTime.getTime()))
        throw new Error("Invalid cursor time");
      return { deviceTime, id: decoded.id };
    } catch {
      throw new BadRequestException({
        code: "INVALID_CURSOR",
        message: "Cursor riwayat tidak valid.",
      });
    }
  }
}
