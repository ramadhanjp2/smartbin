import {
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { readFile, mkdir, stat, writeFile } from "node:fs/promises";
import { join } from "node:path";

const imageTypes = {
  "image/jpeg": {
    extension: "jpg",
    signature: (data: Buffer) =>
      data.length >= 3 &&
      data[0] === 0xff &&
      data[1] === 0xd8 &&
      data[2] === 0xff,
  },
  "image/png": {
    extension: "png",
    signature: (data: Buffer) =>
      data.length >= 8 &&
      data
        .subarray(0, 8)
        .equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])),
  },
  "image/webp": {
    extension: "webp",
    signature: (data: Buffer) =>
      data.length >= 12 &&
      data.toString("ascii", 0, 4) === "RIFF" &&
      data.toString("ascii", 8, 12) === "WEBP",
  },
} as const;

@Injectable()
export class CaptureStorageService {
  constructor(private readonly config: ConfigService) {}

  async save(
    transactionId: string,
    contentType: string,
    data: Buffer,
  ): Promise<void> {
    if (
      !/^[\da-f]{8}-[\da-f]{4}-4[\da-f]{3}-[89ab][\da-f]{3}-[\da-f]{12}$/i.test(
        transactionId,
      )
    )
      throw new ConflictException("transaction_id harus berupa UUID v4.");
    const imageType = imageTypes[contentType as keyof typeof imageTypes];
    if (!imageType || !imageType.signature(data))
      throw new ConflictException(
        "File harus berupa JPEG, PNG, atau WebP yang valid.",
      );

    const directory = this.directory();
    const file = join(directory, `${transactionId}.${imageType.extension}`);
    await mkdir(directory, { recursive: true });
    try {
      await writeFile(file, data, { flag: "wx" });
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "EEXIST") throw error;
      const existing = await readFile(file);
      if (!existing.equals(data))
        throw new ConflictException(
          "Foto untuk transaction_id ini sudah tersimpan.",
        );
    }
  }

  async exists(transactionId: string): Promise<boolean> {
    if (
      !/^[\da-f]{8}-[\da-f]{4}-4[\da-f]{3}-[89ab][\da-f]{3}-[\da-f]{12}$/i.test(
        transactionId,
      )
    )
      return false;
    for (const imageType of Object.values(imageTypes)) {
      try {
        await stat(
          join(this.directory(), `${transactionId}.${imageType.extension}`),
        );
        return true;
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
      }
    }
    return false;
  }

  async read(
    transactionId: string,
  ): Promise<{ data: Buffer; contentType: string }> {
    if (
      !/^[\da-f]{8}-[\da-f]{4}-4[\da-f]{3}-[89ab][\da-f]{3}-[\da-f]{12}$/i.test(
        transactionId,
      )
    )
      throw new NotFoundException("Foto setoran tidak ditemukan.");
    for (const [contentType, imageType] of Object.entries(imageTypes)) {
      try {
        return {
          data: await readFile(
            join(this.directory(), `${transactionId}.${imageType.extension}`),
          ),
          contentType,
        };
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
      }
    }
    throw new NotFoundException("Foto setoran tidak ditemukan.");
  }

  private directory(): string {
    return this.config.get<string>("CAPTURE_STORAGE_DIR", "./data/captures");
  }
}
