import { Injectable, OnModuleDestroy, OnModuleInit } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { MongoClient, Collection, Document, ObjectId } from "mongodb";
import mqtt, { MqttClient } from "mqtt";
import { Observable, Subject } from "rxjs";

export interface TelemetryMessage {
  data: Document;
}

@Injectable()
export class MachineTelemetryService implements OnModuleInit, OnModuleDestroy {
  private mongo?: MongoClient;
  private mqtt?: MqttClient;
  private readonly events = new Subject<TelemetryMessage>();

  constructor(private readonly config: ConfigService) {}

  get stream(): Observable<TelemetryMessage> {
    return this.events.asObservable();
  }

  async onModuleInit(): Promise<void> {
    await this.connectMongo();
    await this.connectMqtt();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.mqtt?.connected) await this.disconnectMqtt();
    await this.mongo?.close();
  }

  private async connectMongo(): Promise<void> {
    const uri = this.config.get<string>("MONGO_URI");
    if (!uri) throw new Error("MONGO_URI is required.");
    this.mongo = new MongoClient(uri);
    await this.mongo.connect();
    await this.createIndexes();
  }

  private database() {
    const name = this.config.get<string>("MONGO_DATABASE", "smartbin_realtime");
    return this.mongo!.db(name);
  }

  private async createIndexes(): Promise<void> {
    const db = this.database();
    await Promise.all([
      db.collection("machine_events").createIndex(
        { receivedAt: -1 },
        { expireAfterSeconds: Number(this.config.get("MONGO_TELEMETRY_TTL_SECONDS", 7776000)) },
      ),
      db.collection("machine_events").createIndex({ deviceId: 1, receivedAt: -1 }),
      db.collection("machine_events").createIndex({ kind: 1, receivedAt: -1 }),
      db.collection("machine_events").createIndex({ topic: 1, receivedAt: -1 }),
      db.collection("machine_latest").createIndex({ deviceId: 1 }, { unique: true }),
      db.collection("machine_latest").createIndex({ updatedAt: -1 }),
      db.collection("machine_commands").createIndex({ deviceId: 1, createdAt: -1 }),
      db.collection("machine_commands").createIndex({ commandId: 1 }, { unique: true }),
    ]);
  }

  private async connectMqtt(): Promise<void> {
    const url = this.config.get<string>("MQTT_URL");
    if (!url) return;

    const options: mqtt.IClientOptions = {
      clientId: this.config.get("MQTT_CLIENT_ID", `smartbin-api-${process.pid}`),
      username: this.config.get<string>("MQTT_USERNAME") || undefined,
      password: this.config.get<string>("MQTT_PASSWORD") || undefined,
      protocolVersion: 4,
      reconnectPeriod: 2000,
      connectTimeout: 15_000,
      clean: true,
    };

    this.mqtt = mqtt.connect(url, options);
    this.mqtt.on("connect", () => {
      const topic = this.config.get("MQTT_SUBSCRIBE_TOPIC", "smartbin/+/telemetry/#");
      this.mqtt?.subscribe(topic, { qos: 1 });
    });
    this.mqtt.on("message", (topic, payload) => void this.handleMessage(topic, payload));
  }

  private async disconnectMqtt(): Promise<void> {
    await new Promise<void>((resolve) => {
      this.mqtt!.end(false, {}, () => resolve());
    });
  }

  private async handleMessage(topic: string, payload: Buffer): Promise<void> {
    let body: Document;
    try {
      body = JSON.parse(payload.toString("utf8"));
    } catch {
      body = { raw: payload.toString("utf8") };
    }

    const parts = topic.split("/");
    const deviceId = String(body.device_id ?? parts[1] ?? "unknown");
    const kind = parts[3] ?? "unknown";
    const deviceTime = this.parseDate(body.timestamp);
    const receivedAt = new Date();
    const document = {
      deviceId,
      kind,
      topic,
      deviceTime,
      receivedAt,
      payload: body,
    };

    const db = this.database();
    try {
      await db.collection("machine_events").insertOne(document);
      await db.collection("machine_latest").updateOne(
        { deviceId },
        {
          $set: { ...document, updatedAt: receivedAt },
          $setOnInsert: { firstSeenAt: receivedAt },
        },
        { upsert: true },
      );
      this.events.next({ data: { ...document, _id: new ObjectId().toString() } });
    } catch (error) {
      console.error("Failed to persist MQTT telemetry", error);
    }
  }

  private parseDate(value: unknown): Date | null {
    if (typeof value !== "string") return null;
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  }

  async latest(deviceId?: string, limit = 100): Promise<Document[]> {
    const db = this.database();
    if (deviceId) {
      const rows = await db.collection("machine_events")
        .find({ deviceId })
        .sort({ receivedAt: -1 })
        .limit(limit)
        .toArray();
      return rows;
    }
    return db.collection("machine_latest")
      .find({})
      .sort({ updatedAt: -1 })
      .limit(limit)
      .toArray();
  }

  async command(deviceId: string, commandId: string, command: string): Promise<void> {
    if (!this.mqtt?.connected) throw new Error("MQTT broker is not connected.");
    const body = { command_id: commandId, command, timestamp: new Date().toISOString() };
    await dbCollection(this.database(), "machine_commands").insertOne({
      deviceId,
      commandId,
      command,
      createdAt: new Date(),
      delivered: false,
    });
    await new Promise<void>((resolve, reject) => {
      this.mqtt!.publish(`smartbin/${deviceId}/command/control`, JSON.stringify(body), { qos: 1 }, (error) => {
        if (error) return reject(error);
        void dbCollection(this.database(), "machine_commands")
          .updateOne({ commandId }, { $set: { delivered: true, deliveredAt: new Date() } })
          .then(() => resolve())
          .catch(reject);
      });
    });
  }
}

function dbCollection(database: ReturnType<MongoClient["db"]>, name: string): Collection<Document> {
  return database.collection(name);
}
