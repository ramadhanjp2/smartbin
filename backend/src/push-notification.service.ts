import { Injectable, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { InjectRepository } from "@nestjs/typeorm";
import {
  App,
  applicationDefault,
  getApps,
  initializeApp,
} from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";
import { createHash } from "node:crypto";
import { In, Repository } from "typeorm";
import { PushDeviceEntity } from "./entities/push-device.entity";

export interface PushNotification {
  kind: string;
  title: string;
  body: string;
  depositId?: string | null;
}

@Injectable()
export class PushNotificationService {
  private readonly logger = new Logger(PushNotificationService.name);
  private readonly firebaseApp?: App;

  constructor(
    @InjectRepository(PushDeviceEntity)
    private readonly devices: Repository<PushDeviceEntity>,
    config: ConfigService,
  ) {
    const projectId = config.get<string>("FIREBASE_PROJECT_ID");
    if (!projectId) {
      this.logger.warn(
        "FCM dinonaktifkan: FIREBASE_PROJECT_ID belum dikonfigurasi.",
      );
      return;
    }
    this.firebaseApp =
      getApps().find((app) => app.name === "smartbin") ??
      initializeApp(
        { credential: applicationDefault(), projectId },
        "smartbin",
      );
  }

  async registerDevice(userId: string, token: string): Promise<void> {
    const tokenHash = this.hashToken(token);
    const existing = await this.devices.findOneBy({ tokenHash });
    if (existing) {
      existing.userId = userId;
      existing.token = token;
      await this.devices.save(existing);
      return;
    }
    await this.devices.save(
      this.devices.create({ userId, token, tokenHash }),
    );
  }

  async unregisterDevice(userId: string, token: string): Promise<void> {
    await this.devices.delete({ userId, tokenHash: this.hashToken(token) });
  }

  async sendToUser(
    userId: string,
    notification: PushNotification,
  ): Promise<void> {
    if (!this.firebaseApp) return;
    try {
      const devices = await this.devices.findBy({ userId });
      for (let offset = 0; offset < devices.length; offset += 500) {
        const batch = devices.slice(offset, offset + 500);
        const result = await getMessaging(this.firebaseApp).sendEachForMulticast({
          fids: batch.map((device) => device.token),
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: {
            kind: notification.kind,
            ...(notification.depositId
              ? { depositId: notification.depositId }
              : {}),
          },
          android: {
            notification: { channelId: "smartbin_notifications" },
          },
        });
        const invalidHashes = batch
          .filter((_, index) => {
            const error = result.responses[index].error;
            return (
              error?.code === "messaging/installation-id-not-registered" ||
              error?.code === "messaging/invalid-registration-token" ||
              error?.code === "messaging/registration-token-not-registered"
            );
          })
          .map((device) => device.tokenHash);
        if (invalidHashes.length) {
          await this.devices.delete({ tokenHash: In(invalidHashes) });
        }
        if (result.failureCount) {
          this.logger.warn(
            `FCM gagal mengirim ke ${result.failureCount} dari ${batch.length} perangkat untuk pengguna ${userId}.`,
          );
        }
      }
    } catch (error) {
      this.logger.error(
        `FCM gagal mengirim notifikasi untuk pengguna ${userId}.`,
        error instanceof Error ? error.stack : String(error),
      );
    }
  }

  private hashToken(token: string): string {
    return createHash("sha256").update(token).digest("hex");
  }
}
