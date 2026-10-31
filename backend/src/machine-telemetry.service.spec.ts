import { ConfigService } from "@nestjs/config";
import { MongoClient, ObjectId } from "mongodb";
import { SmartbinService } from "./smartbin.service";
import { MachineTelemetryService } from "./machine-telemetry.service";

describe("MachineTelemetryService", () => {
  it("builds a MongoDB URI from mounted credentials when no URI is configured", () => {
    const service = new MachineTelemetryService(
      new ConfigService({
        MONGO_USERNAME: "smart bin",
        MONGO_PASSWORD: "pa:ss/word",
        MONGO_DATABASE: "smartbin_realtime",
      }),
      {} as unknown as SmartbinService,
    );

    expect(service["buildMongoUriFromConfig"]()).toBe(
      "mongodb://smart%20bin:pa%3Ass%2Fword@mongodb:27017/smartbin_realtime?authSource=admin",
    );
  });

  it("does not include the inserted event _id in the machine snapshot update", async () => {
    const insertedId = new ObjectId();
    const updateOne = jest.fn().mockResolvedValue({ acknowledged: true });
    const machineLatest = { updateOne };
    const machineEvents = {
      insertOne: jest.fn(async (document: Record<string, unknown>) => {
        document._id = insertedId;
        return { acknowledged: true, insertedId };
      }),
    };
    const database = {
      collection: jest.fn((name: string) =>
        name === "machine_events" ? machineEvents : machineLatest,
      ),
    };
    const mongo = { db: jest.fn(() => database) };
    const smartbin = {
      validateMqttDevice: jest.fn().mockResolvedValue(undefined),
    };
    const service = new MachineTelemetryService(
      new ConfigService(),
      smartbin as unknown as SmartbinService,
    );
    service["mongo"] = mongo as unknown as MongoClient;

    await service["handleMessage"](
      "smartbin/esp1/telemetry/status",
      Buffer.from('{"timestamp":"2026-10-31T09:30:00Z","state":"IDLE"}'),
    );

    const update = updateOne.mock.calls[0][1] as {
      $set: Record<string, unknown>;
    };
    expect(update.$set).not.toHaveProperty("_id");
    expect(update.$set).toHaveProperty("deviceId", "esp1");
    expect(machineEvents.insertOne).toHaveBeenCalledTimes(1);
    expect(smartbin.validateMqttDevice).toHaveBeenCalledWith("esp1");
  });

  it("does not let non-status telemetry overwrite the latest machine snapshot", async () => {
    const updateOne = jest.fn();
    const machineEvents = {
      insertOne: jest.fn().mockResolvedValue({
        acknowledged: true,
        insertedId: new ObjectId(),
      }),
    };
    const database = {
      collection: jest.fn((name: string) =>
        name === "machine_events"
          ? machineEvents
          : { updateOne, findOne: jest.fn() },
      ),
    };
    const service = new MachineTelemetryService(
      new ConfigService(),
      {} as unknown as SmartbinService,
    );
    service["mongo"] = {
      db: jest.fn(() => database),
    } as unknown as MongoClient;

    await service["handleMessage"](
      "smartbin/esp1/telemetry/sensor",
      Buffer.from('{"timestamp":"2026-10-31T09:30:00Z","distance_cm":48}'),
    );

    expect(machineEvents.insertOne).toHaveBeenCalledTimes(1);
    expect(updateOne).not.toHaveBeenCalled();
  });
});
