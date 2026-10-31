import {
  ConflictException,
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  OnModuleInit,
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
import { CaptureStorageService } from "./capture-storage.service";
import {
  DepositQueryDto,
  IngestDepositDto,
  LoginDto,
  MachineStatusDto,
  RegisterDto,
  UpdateMeDto,
  UpdateRatesDto,
  CreateAdminUserDto,
  UpdateAdminUserDto,
  UpdateMachineDto,
} from "./dto";

@Injectable()
export class SmartbinService implements OnModuleInit {
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
    private readonly captures: CaptureStorageService,
  ) {}

  async onModuleInit(): Promise<void> {
    const existing = await this.machinesRepo.findOne({
      where: { code: "bin-01" },
    });
    if (!existing) {
      await this.machinesRepo.save(
        this.machinesRepo.create({
          code: "bin-01",
          name: "SmartBIN Unit #01",
          location: "Lokasi pemasangan",
          status: "OFFLINE",
          organicFill: 0,
          inorganicFill: 0,
          lastSeen: null,
        }),
      );
    }
  }

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
    if (!user.active) {
      throw new UnauthorizedException({
        code: "ACCOUNT_INACTIVE",
        message: "Akun dinonaktifkan. Hubungi administrator.",
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
    const byType = (type: "ORGANIK" | "ANORGANIK" | "RESIDU") =>
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
      residuG: byType("RESIDU").reduce(
        (sum, deposit) => sum + deposit.weightG,
        0,
      ),
      residuCount: byType("RESIDU").length,
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
      data: await Promise.all(
        data.map((deposit) => this.publicDeposit(deposit)),
      ),
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
      active: user.active !== false,
    }));
  }

  async createAdminUser(dto: CreateAdminUserDto): Promise<unknown> {
    const nikHash = this.nikHash(dto.nik);
    const email = dto.email.trim().toLowerCase();
    const exists = await this.users.findOne({
      where: [{ nikHash }, { email }],
    });
    if (exists)
      throw new ConflictException({
        code: "ACCOUNT_EXISTS",
        message: "NIK atau email sudah digunakan.",
      });
    const user = this.users.create({
      nikHash,
      email,
      name: dto.name.trim(),
      passwordHash: await bcrypt.hash(dto.password, 12),
      role: dto.role ?? "user",
      active: true,
    });
    await this.users.save(user);
    return {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      active: true,
    };
  }

  async updateAdminUser(id: string, dto: UpdateAdminUserDto): Promise<unknown> {
    const user = await this.users.findOneBy({ id });
    if (!user)
      throw new NotFoundException({
        code: "USER_NOT_FOUND",
        message: "Pengguna tidak ditemukan.",
      });
    if (dto.name !== undefined) user.name = dto.name.trim();
    if (dto.email !== undefined) {
      const email = dto.email.trim().toLowerCase();
      const duplicate = await this.users.findOne({ where: { email } });
      if (duplicate && duplicate.id !== id)
        throw new ConflictException({
          code: "EMAIL_EXISTS",
          message: "Email sudah digunakan.",
        });
      user.email = email;
    }
    if (dto.role !== undefined) user.role = dto.role;
    if (dto.password !== undefined)
      user.passwordHash = await bcrypt.hash(dto.password, 12);
    if (dto.active !== undefined) user.active = dto.active;
    await this.users.save(user);
    return {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      active: user.active !== false,
    };
  }

  async deleteAdminUser(
    id: string,
    currentUserId: string,
  ): Promise<{ success: true }> {
    if (id === currentUserId)
      throw new BadRequestException({
        code: "SELF_DELETE",
        message: "Tidak dapat menghapus akun yang sedang digunakan.",
      });
    const user = await this.users.findOneBy({ id });
    if (!user)
      throw new NotFoundException({
        code: "USER_NOT_FOUND",
        message: "Pengguna tidak ditemukan.",
      });
    await this.users.remove(user);
    return { success: true };
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
      type:
        deposit.type === "ORGANIK"
          ? "Organik"
          : deposit.type === "RESIDU"
            ? "Residu"
            : "Anorganik",
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
      deviceId: this.deviceIdForMachineCode(machine.code),
      name: machine.name,
      location: machine.location,
      status: machine.status,
      lastSeen: machine.lastSeen?.toISOString() ?? null,
      organicFill: machine.organicFill,
      inorganicFill: machine.inorganicFill,
      residuFill: machine.residuFill,
      organicCmLeft: machine.organikCm,
      inorganicCmLeft: machine.anorganikCm,
      residuCmLeft: machine.residuCm,
    }));
  }

  async resolveDeviceId(idOrCode: string): Promise<string> {
    const machine = await this.machinesRepo.findOne({
      where: [{ id: idOrCode }, { code: idOrCode }],
    });
    if (!machine)
      throw new NotFoundException({
        code: "MACHINE_NOT_FOUND",
        message: "Mesin tidak ditemukan.",
      });
    const deviceId = this.deviceIdForMachineCode(machine.code);
    if (!deviceId)
      throw new ConflictException({
        code: "MACHINE_NOT_CONFIGURED",
        message: "ID perangkat MQTT belum dikonfigurasi untuk mesin ini.",
      });
    return deviceId;
  }

  async validateCaptureDevice(deviceId: string): Promise<void> {
    const machineCode = this.machineCodeForDeviceId(deviceId);
    if (
      !machineCode ||
      !(await this.machinesRepo.findOneBy({ code: machineCode }))
    )
      throw new NotFoundException({
        code: "MACHINE_NOT_FOUND",
        message: "Perangkat MQTT tidak terdaftar.",
      });
  }

  async assertCaptureAccess(
    transactionId: string,
    userId: string,
    role: UserRole,
  ): Promise<void> {
    const deposit = await this.depositsRepo.findOneBy({ transactionId });
    if (!deposit || (role !== "admin" && deposit.userId !== userId))
      throw new NotFoundException({
        code: "CAPTURE_NOT_FOUND",
        message: "Foto setoran tidak ditemukan.",
      });
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
    const uidHash = this.cardHash(dto.uid);
    return this.createDeposit(
      machine,
      dto.transactionId,
      uidHash,
      dto.type,
      dto.itemLabel,
      dto.weightG,
      new Date(dto.deviceTime),
    );
  }

  async authenticateMqttCard(uidHash: string): Promise<{
    found: boolean;
    name: string | null;
    balance: number;
  }> {
    if (!/^[a-f\d]{64}$/i.test(uidHash))
      throw new BadRequestException("uid_hash harus berupa HMAC-SHA256 hex.");
    const card = await this.cards.findOneBy({ uidHash: uidHash.toLowerCase() });
    if (!card) return { found: false, name: null, balance: 0 };
    const user = await this.users.findOneBy({ id: card.userId });
    if (!user || !user.active) return { found: false, name: null, balance: 0 };
    const entries = await this.ledger.find({ where: { userId: user.id } });
    return {
      found: true,
      name: user.name,
      balance: entries.reduce((sum, entry) => sum + entry.delta, 0),
    };
  }

  async ingestMqttDeposit(
    deviceId: string,
    body: Record<string, unknown>,
  ): Promise<{
    transactionId: string;
    points: number;
    balance: number;
    status: string;
    duplicate: boolean;
  }> {
    const machineCode = this.machineCodeForDeviceId(deviceId);
    if (!machineCode)
      throw new NotFoundException(`MQTT device is not mapped: ${deviceId}`);
    const machine = await this.machinesRepo.findOneBy({ code: machineCode });
    if (!machine)
      throw new NotFoundException(`Machine is not provisioned: ${machineCode}`);
    const transactionId = body.transaction_id;
    const uidHash = body.uid_hash;
    const type = body.type;
    const weightG = body.weight_g;
    const timestamp = body.timestamp;
    const validType =
      type === "ORGANIK" || type === "ANORGANIK" || type === "RESIDU";
    if (
      typeof transactionId !== "string" ||
      !/^[\da-f]{8}-[\da-f]{4}-4[\da-f]{3}-[89ab][\da-f]{3}-[\da-f]{12}$/i.test(
        transactionId,
      ) ||
      typeof uidHash !== "string" ||
      !/^[a-f\d]{64}$/i.test(uidHash) ||
      !validType ||
      !Number.isInteger(weightG) ||
      Number(weightG) < 1 ||
      Number(weightG) > 100_000 ||
      typeof timestamp !== "string" ||
      Number.isNaN(Date.parse(timestamp))
    )
      throw new BadRequestException("Payload setoran MQTT tidak valid.");

    const result = await this.createDeposit(
      machine,
      transactionId,
      uidHash.toLowerCase(),
      type,
      typeof body.item_label === "string" ? body.item_label.slice(0, 120) : "",
      Number(weightG),
      new Date(timestamp),
    );
    const deposit = await this.depositsRepo.findOneBy({ transactionId });
    const card = deposit?.userId
      ? await this.users.findOneBy({ id: deposit.userId })
      : null;
    const entries = card
      ? await this.ledger.find({ where: { userId: card.id } })
      : [];
    return {
      transactionId,
      points: result.points,
      balance: entries.reduce((sum, entry) => sum + entry.delta, 0),
      status: result.status,
      duplicate: result.duplicate,
    };
  }

  async updateMachineFromMqtt(
    deviceId: string,
    body: Record<string, unknown>,
  ): Promise<void> {
    const machineCode = this.machineCodeForDeviceId(deviceId);
    if (!machineCode)
      throw new NotFoundException(`MQTT device is not mapped: ${deviceId}`);
    const machine = await this.machinesRepo.findOneBy({ code: machineCode });
    if (!machine)
      throw new NotFoundException(`Machine is not provisioned: ${machineCode}`);
    const state = body.state;
    if (
      state === "IDLE" ||
      state === "SIBUK" ||
      state === "SIAP" ||
      state === "PENUH" ||
      state === "GANGGUAN" ||
      state === "OFFLINE"
    )
      machine.status = state;
    const compartments = body.compartments;
    if (compartments && typeof compartments === "object") {
      const fills = compartments as Record<string, unknown>;
      const organicFill = this.fillPercentage(fills.organik_fill_pct);
      const inorganicFill = this.fillPercentage(fills.anorganik_fill_pct);
      const residuFill = this.fillPercentage(fills.residu_fill_pct);
      if (organicFill !== null) machine.organicFill = organicFill;
      if (inorganicFill !== null) machine.inorganicFill = inorganicFill;
      if (residuFill !== null) machine.residuFill = residuFill;
    }
    const distances = body.sekat_cm;
    if (distances && typeof distances === "object") {
      const values = distances as Record<string, unknown>;
      const organicCm = this.sensorDistance(values.organik);
      const inorganicCm = this.sensorDistance(values.anorganik);
      const residuCm = this.sensorDistance(values.residu);
      if (organicCm !== null) machine.organikCm = organicCm;
      if (inorganicCm !== null) machine.anorganikCm = inorganicCm;
      if (residuCm !== null) machine.residuCm = residuCm;
    }
    machine.lastSeen = new Date();
    await this.machinesRepo.save(machine);
  }

  private async createDeposit(
    machine: MachineEntity,
    transactionId: string,
    uidHash: string,
    type: "ORGANIK" | "ANORGANIK" | "RESIDU",
    itemLabel: string,
    weightG: number,
    deviceTime: Date,
  ): Promise<{
    transactionId: string;
    points: number;
    status: string;
    duplicate: boolean;
  }> {
    const duplicate = await this.depositsRepo.findOneBy({ transactionId });
    if (duplicate)
      return {
        transactionId: duplicate.transactionId,
        points: duplicate.points,
        status: duplicate.status,
        duplicate: true,
      };
    const card = await this.cards.findOneBy({ uidHash });
    const rates = await this.getRates();
    const rate =
      type === "ORGANIK"
        ? rates.organikPerKg
        : type === "ANORGANIK"
          ? rates.anorganikPerKg
          : 0;
    const points = calculatePoints(weightG, rate);
    const status = card ? "CREDITED" : "HELD";
    try {
      const deposit = await this.dataSource.transaction(async (manager) => {
        const saved = await manager.getRepository(DepositEntity).save(
          manager.getRepository(DepositEntity).create({
            transactionId,
            machineId: machine.id,
            userId: card?.userId ?? null,
            uidHash,
            type,
            itemLabel,
            weightG,
            points,
            ratePerKg: rate,
            deviceTime,
            status,
          }),
        );
        if (card) {
          await manager.getRepository(PointLedgerEntity).save(
            manager.getRepository(PointLedgerEntity).create({
              userId: card.userId,
              delta: points,
              reason: "DEPOSIT",
              referenceId: transactionId,
            }),
          );
          await manager.getRepository(NotificationEntity).save(
            manager.getRepository(NotificationEntity).create({
              userId: card.userId,
              kind: "deposit",
              title: "Setoran berhasil tercatat",
              body: `Setoran ${weightG} g ${type.toLowerCase()} memperoleh ${points} poin.`,
              referenceId: transactionId,
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
        const duplicateDeposit = await this.depositsRepo.findOneBy({
          transactionId,
        });
        if (duplicateDeposit)
          return {
            transactionId,
            points: duplicateDeposit.points,
            status: duplicateDeposit.status,
            duplicate: true,
          };
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
    if (dto.residuFill !== undefined) machine.residuFill = dto.residuFill;
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
    user.card = await this.cards.findOneBy({ userId: user.id });
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

  private async publicDeposit(deposit: DepositEntity): Promise<unknown> {
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
      photoUrl: (await this.captures.exists(deposit.transactionId))
        ? `captures/${encodeURIComponent(deposit.transactionId)}`
        : null,
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

  private machineCodeForDeviceId(deviceId: string): string | undefined {
    const mapping = this.config.get(
      "MQTT_DEVICE_MACHINE_MAP",
      "esp1=bin-01,esp2=bin-02",
    );
    for (const entry of mapping.split(",")) {
      const [configuredDeviceId, machineCode] = entry
        .split("=")
        .map((part: string) => part.trim());
      if (configuredDeviceId === deviceId && machineCode) return machineCode;
    }
    return undefined;
  }

  private deviceIdForMachineCode(machineCode: string): string | null {
    const mapping = this.config.get(
      "MQTT_DEVICE_MACHINE_MAP",
      "esp1=bin-01,esp2=bin-02",
    );
    for (const entry of mapping.split(",")) {
      const [deviceId, configuredMachineCode] = entry
        .split("=")
        .map((part: string) => part.trim());
      if (configuredMachineCode === machineCode && deviceId) return deviceId;
    }
    return null;
  }

  private fillPercentage(value: unknown): number | null {
    if (typeof value !== "number" || !Number.isFinite(value)) return null;
    return Math.max(0, Math.min(100, Math.round(value)));
  }

  private sensorDistance(value: unknown): number | null {
    if (
      typeof value !== "number" ||
      !Number.isInteger(value) ||
      value < 0 ||
      value > 65_535
    )
      return null;
    return value;
  }

  private hashToken(token: string): string {
    return createHmac(
      "sha256",
      this.config.getOrThrow<string>("JWT_ACCESS_SECRET"),
    )
      .update(token)
      .digest("hex");
  }

  assertMachineKey(provided: string | undefined): void {
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
