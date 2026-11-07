import { ConfigService } from "@nestjs/config";
import { createHash } from "node:crypto";
import { Repository } from "typeorm";
import { PushDeviceEntity } from "./entities/push-device.entity";
import { PushNotificationService } from "./push-notification.service";

describe("PushNotificationService", () => {
  const token = "fcm-registration-token";

  function service(devices: Record<string, jest.Mock>) {
    const config = new ConfigService();
    jest.spyOn(config, "get").mockReturnValue(undefined);
    return new PushNotificationService(
      devices as unknown as Repository<PushDeviceEntity>,
      config,
    );
  }

  it("registers a token using a hash and assigns it to the current user", async () => {
    const devices = {
      findOneBy: jest.fn().mockResolvedValue(null),
      create: jest.fn((device) => device),
      save: jest.fn().mockResolvedValue(undefined),
    };

    await service(devices).registerDevice("user-1", token);

    expect(devices.findOneBy).toHaveBeenCalledWith({
      tokenHash: createHash("sha256").update(token).digest("hex"),
    });
    expect(devices.create).toHaveBeenCalledWith({
      userId: "user-1",
      token,
      tokenHash: createHash("sha256").update(token).digest("hex"),
    });
    expect(devices.save).toHaveBeenCalledTimes(1);
  });

  it("reassigns an existing device token to the newly authenticated user", async () => {
    const existing = { userId: "old-user", token };
    const devices = {
      findOneBy: jest.fn().mockResolvedValue(existing),
      save: jest.fn().mockResolvedValue(undefined),
    };

    await service(devices).registerDevice("new-user", token);

    expect(existing.userId).toBe("new-user");
    expect(devices.save).toHaveBeenCalledWith(existing);
  });

  it("unregisters only the matching user's token hash", async () => {
    const devices = { delete: jest.fn().mockResolvedValue({ affected: 1 }) };

    await service(devices).unregisterDevice("user-1", token);

    expect(devices.delete).toHaveBeenCalledWith({
      userId: "user-1",
      tokenHash: createHash("sha256").update(token).digest("hex"),
    });
  });
});
