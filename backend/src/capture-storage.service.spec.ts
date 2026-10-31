import { ConfigService } from "@nestjs/config";
import { ConflictException, NotFoundException } from "@nestjs/common";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { CaptureStorageService } from "./capture-storage.service";

describe("CaptureStorageService", () => {
  let directory: string;
  let storage: CaptureStorageService;
  const transactionId = "8f14e45f-ea2b-4c1a-9c3d-71b0f2a65e40";
  const image = Buffer.from([0xff, 0xd8, 0xff, 0x00]);

  beforeEach(async () => {
    directory = await mkdtemp(join(tmpdir(), "smartbin-captures-"));
    storage = new CaptureStorageService(
      new ConfigService({ CAPTURE_STORAGE_DIR: directory }),
    );
  });

  afterEach(async () => {
    await rm(directory, { recursive: true, force: true });
  });

  it("persists a validated image and allows an identical retry", async () => {
    await storage.save(transactionId, "image/jpeg", image);
    await storage.save(transactionId, "image/jpeg", image);

    expect(await storage.exists(transactionId)).toBe(true);
    await expect(storage.read(transactionId)).resolves.toEqual({
      data: image,
      contentType: "image/jpeg",
    });
  });

  it("rejects a different image for an existing transaction", async () => {
    await storage.save(transactionId, "image/jpeg", image);

    await expect(
      storage.save(
        transactionId,
        "image/jpeg",
        Buffer.from([0xff, 0xd8, 0xff, 0x01]),
      ),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it("does not report a photo for an invalid transaction ID", async () => {
    expect(await storage.exists("../capture")).toBe(false);
    await expect(storage.read("../capture")).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
