import {
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
} from "@nestjs/common";
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
import { map, Observable } from "rxjs";

@Controller()
export class SmartbinController {
  constructor(
    private readonly service: SmartbinService,
    private readonly telemetry: MachineTelemetryService,
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
    return this.service.updateMachine(id, dto);
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
  machines(): Promise<unknown> {
    return this.service.machines();
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
  ): Promise<unknown> {
    this.service.assertAdmin(req.user.role);
    return this.service.resetMachine(id);
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
    return this.service.updateMachineStatus(id, machineKey, dto);
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
}
