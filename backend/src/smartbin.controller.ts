import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  Param,
  Patch,
  Post,
  Put,
  Query,
  Req,
  UseGuards,
  Sse,
  MessageEvent,
  StreamableFile,
  UploadedFile,
  UseInterceptors,
} from "@nestjs/common";
import { FileInterceptor } from "@nestjs/platform-express";
import {
  AccessTokenGuard,
  AuthenticatedRequest,
} from "./auth/access-token.guard";
import {
  CardLinkDto,
  DepositQueryDto,
  IngestDepositDto,
  LoginDto,
  MachineStatusDto,
  RefreshDto,
  RegisterDto,
  UnlinkCardDto,
  UpdateMeDto,
  UpdateRatesDto,
  UpdateMachineDto,
  CreateAdminUserDto,
  UpdateAdminUserDto,
} from "./dto";
import { SmartbinService } from "./smartbin.service";
import { MachineTelemetryService } from "./machine-telemetry.service";
import { CaptureStorageService } from "./capture-storage.service";
import { mergeMachineTelemetry } from "./machine-telemetry.mapper";
import { map, Observable } from "rxjs";

@Controller()
export class SmartbinController {
  constructor(
    private readonly service: SmartbinService,
    private readonly telemetry: MachineTelemetryService,
    private readonly captures: CaptureStorageService,
  ) {}

  @Get("health")
  health(): { status: string } {
    return { status: "ok" };
  }

  @Post("auth/register")
  register(@Body() dto: RegisterDto): Promise<unknown> {
    return this.service.register(dto);
  }

  @Post("auth/login")
  login(@Body() dto: LoginDto): Promise<unknown> {
    return this.service.login(dto);
  }

  @Post("auth/refresh")
  refresh(@Body() dto: RefreshDto): Promise<unknown> {
    return this.service.refresh(dto.refreshToken);
  }

  @UseGuards(AccessTokenGuard)
  @Post("auth/logout")
  logout(@Body() dto: RefreshDto): Promise<{ success: true }> {
    return this.service.logout(dto.refreshToken);
  }

  @UseGuards(AccessTokenGuard)
  @Get("me")
  me(@Req() req: AuthenticatedRequest): Promise<unknown> {
    return this.service.me(req.user.sub);
  }

  @UseGuards(AccessTokenGuard)
  @Patch("me")
  updateMe(
    @Req() req: AuthenticatedRequest,
    @Body() dto: UpdateMeDto,
  ): Promise<unknown> {
    return this.service.updateMe(req.user.sub, dto);
  }

  @UseGuards(AccessTokenGuard)
  @Post("cards/link")
  linkCard(
    @Req() req: AuthenticatedRequest,
    @Body() dto: CardLinkDto,
  ): Promise<unknown> {
    return this.service.linkCard(req.user.sub, dto.uid);
  }

  @UseGuards(AccessTokenGuard)
  @Delete("cards/me")
  unlinkCard(
    @Req() req: AuthenticatedRequest,
    @Body() dto: UnlinkCardDto,
  ): Promise<{ success: true }> {
    return this.service.unlinkCard(req.user.sub, dto.password);
  }

  @UseGuards(AccessTokenGuard)
  @Get("points/summary")
  pointsSummary(@Req() req: AuthenticatedRequest): Promise<unknown> {
    return this.service.pointsSummary(req.user.sub);
  }

  @UseGuards(AccessTokenGuard)
  @Get("deposits")
  deposits(
    @Req() req: AuthenticatedRequest,
    @Query() query: DepositQueryDto,
  ): Promise<unknown> {
    return this.service.deposits(req.user.sub, query);
  }

  @UseGuards(AccessTokenGuard)
  @Get("deposits/:id")
  deposit(
    @Req() req: AuthenticatedRequest,
    @Param("id") id: string,
  ): Promise<unknown> {
    return this.service.deposit(req.user.sub, id);
  }

  @Post("captures")
  @UseInterceptors(
    FileInterceptor("photo", { limits: { fileSize: 5 * 1024 * 1024 } }),
  )
  async uploadCapture(
    @Headers("x-machine-api-key") machineKey: string | undefined,
    @Headers("idempotency-key") idempotencyKey: string | undefined,
    @Body() body: Record<string, unknown>,
    @UploadedFile() file?: Express.Multer.File,
  ): Promise<{ transactionId: string; photoUrl: string }> {
    this.service.assertMachineKey(machineKey);
    const transactionId = body.transaction_id;
    const deviceId = body.bin_id;
    const wasteType = body.class;
    const confidence = Number(body.confidence);
    if (
      typeof transactionId !== "string" ||
      idempotencyKey !== transactionId ||
      typeof deviceId !== "string" ||
      !["organik", "anorganik", "residu"].includes(String(wasteType)) ||
      !Number.isFinite(confidence) ||
      confidence < 0 ||
      confidence > 1 ||
      !file
    )
      throw new BadRequestException("Metadata unggahan foto tidak valid.");
    await this.service.validateCaptureDevice(deviceId);
    await this.captures.save(transactionId, file.mimetype, file.buffer);
    return {
      transactionId,
      photoUrl: `captures/${encodeURIComponent(transactionId)}`,
    };
  }

  @UseGuards(AccessTokenGuard)
  @Get("captures/:transactionId")
  async capture(
    @Req() req: AuthenticatedRequest,
    @Param("transactionId") transactionId: string,
  ): Promise<StreamableFile> {
    await this.service.assertCaptureAccess(
      transactionId,
      req.user.sub,
      req.user.role,
    );
    const image = await this.captures.read(transactionId);
    return new StreamableFile(image.data, {
      type: image.contentType,
      disposition: "inline",
    });
  }

  @UseGuards(AccessTokenGuard)
  @Get("rates")
  rates(): Promise<unknown> {
    return this.service.rates();
  }

  @UseGuards(AccessTokenGuard)
  @Get("admin/users")
  adminUsers(@Req() req: AuthenticatedRequest): Promise<unknown> {
    this.service.assertAdmin(req.user.role);
    return this.service.adminUsers();
  }

  @UseGuards(AccessTokenGuard)
  @Post("admin/users")
  createAdminUser(
    @Req() req: AuthenticatedRequest,
    @Body() dto: CreateAdminUserDto,
  ): Promise<unknown> {
    this.service.assertAdmin(req.user.role);
    return this.service.createAdminUser(dto);
  }

  @UseGuards(AccessTokenGuard)
  @Patch("admin/users/:id")
  updateAdminUser(
    @Req() req: AuthenticatedRequest,
    @Param("id") id: string,
    @Body() dto: UpdateAdminUserDto,
  ): Promise<unknown> {
    this.service.assertAdmin(req.user.role);
    return this.service.updateAdminUser(id, dto);
  }

  @UseGuards(AccessTokenGuard)
  @Delete("admin/users/:id")
  deleteAdminUser(
    @Req() req: AuthenticatedRequest,
    @Param("id") id: string,
  ): Promise<unknown> {
    this.service.assertAdmin(req.user.role);
    return this.service.deleteAdminUser(id, req.user.sub);
  }

  @UseGuards(AccessTokenGuard)
  @Put("admin/machines/:id")
  updateMachine(
    @Req() req: AuthenticatedRequest,
    @Param("id") id: string,
    @Body() dto: UpdateMachineDto,
  ): Promise<unknown> {
    this.service.assertAdmin(req.user.role);
    return this.service
      .updateMachine(id, dto)
      .then(() => this.machinesWithTelemetry());
  }

  @UseGuards(AccessTokenGuard)
  @Get("admin/history")
  adminHistory(@Req() req: AuthenticatedRequest): Promise<unknown> {
    this.service.assertAdmin(req.user.role);
    return this.service.adminHistory();
  }

  @UseGuards(AccessTokenGuard)
  @Put("admin/rates")
  updateRates(
    @Req() req: AuthenticatedRequest,
    @Body() dto: UpdateRatesDto,
  ): Promise<unknown> {
    this.service.assertAdmin(req.user.role);
    return this.service.updateRates(dto);
  }

  @UseGuards(AccessTokenGuard)
  @Get("machines")
  async machines(): Promise<unknown> {
    return this.machinesWithTelemetry();
  }

  @UseGuards(AccessTokenGuard)
  @Sse("machines/realtime")
  machineRealtime(): Observable<MessageEvent> {
    return this.telemetry.stream.pipe(
      map(({ data }) => ({ data: JSON.stringify(data) })),
    );
  }

  @UseGuards(AccessTokenGuard)
  @Get("machines/telemetry")
  telemetryLatest(@Query("deviceId") deviceId?: string): Promise<unknown> {
    return this.telemetry.latest(deviceId);
  }

  @UseGuards(AccessTokenGuard)
  @Get("machines/:deviceId/telemetry")
  telemetryHistory(
    @Param("deviceId") deviceId: string,
    @Query("limit") limit?: string,
  ): Promise<unknown> {
    const parsedLimit = Math.min(Math.max(Number(limit ?? 100), 1), 500);
    return this.telemetry.latest(deviceId, parsedLimit);
  }

  @UseGuards(AccessTokenGuard)
  @Post("machines/:deviceId/command")
  commandMachine(
    @Req() req: AuthenticatedRequest,
    @Param("deviceId") deviceId: string,
    @Body() body: { command: string; commandId?: string },
  ): Promise<{ success: true }> {
    this.service.assertAdmin(req.user.role);
    return this.telemetry
      .command(
        deviceId,
        body.commandId ?? `cmd-${deviceId}-${Date.now()}`,
        body.command,
      )
      .then(() => ({ success: true }));
  }

  @UseGuards(AccessTokenGuard)
  @Post("machines/:id/reset")
  resetMachine(
    @Req() req: AuthenticatedRequest,
    @Param("id") id: string,
  ): Promise<{ success: true; command: string }> {
    this.service.assertAdmin(req.user.role);
    return this.service
      .resolveDeviceId(id)
      .then((deviceId) =>
        this.telemetry.command(
          deviceId,
          `reset-${deviceId}-${Date.now()}`,
          "reset_gangguan",
        ),
      )
      .then(() => ({ success: true, command: "reset_gangguan" }));
  }

  @Post("machines/:id/deposits")
  ingestDeposit(
    @Param("id") id: string,
    @Headers("x-machine-api-key") machineKey: string | undefined,
    @Body() dto: IngestDepositDto,
  ): Promise<unknown> {
    return this.service.ingestDeposit(id, machineKey, dto);
  }

  @Post("machines/:id/status")
  machineStatus(
    @Param("id") id: string,
    @Headers("x-machine-api-key") machineKey: string | undefined,
    @Body() dto: MachineStatusDto,
  ): Promise<unknown> {
    return this.service
      .resolveStatusDeviceId(id, machineKey)
      .then((deviceId) =>
        this.telemetry.recordStatus(deviceId, {
          state: dto.status,
          timestamp: new Date().toISOString(),
          compartments: {
            ...(dto.organicFill !== undefined
              ? { organik_fill_pct: dto.organicFill }
              : {}),
            ...(dto.inorganicFill !== undefined
              ? { anorganik_fill_pct: dto.inorganicFill }
              : {}),
            ...(dto.residuFill !== undefined
              ? { residu_fill_pct: dto.residuFill }
              : {}),
          },
        }),
      )
      .then(() => ({ success: true }));
  }

  @UseGuards(AccessTokenGuard)
  @Get("notifications")
  notifications(@Req() req: AuthenticatedRequest): Promise<unknown> {
    return this.service.notifications(req.user.sub);
  }

  @UseGuards(AccessTokenGuard)
  @Post("notifications/:id/read")
  markRead(
    @Req() req: AuthenticatedRequest,
    @Param("id") id: string,
  ): Promise<{ success: true }> {
    return this.service.markNotificationRead(req.user.sub, id);
  }

  @UseGuards(AccessTokenGuard)
  @Post("notifications/read-all")
  markAllRead(@Req() req: AuthenticatedRequest): Promise<{ success: true }> {
    return this.service.markAllNotificationsRead(req.user.sub);
  }

  private async machinesWithTelemetry(): Promise<Record<string, unknown>[]> {
    const [machines, snapshots] = await Promise.all([
      this.service.machines(),
      this.telemetry.latestStatuses(),
    ]);
    return mergeMachineTelemetry(machines, snapshots);
  }
}
