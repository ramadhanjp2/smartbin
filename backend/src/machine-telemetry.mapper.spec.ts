import { mergeMachineTelemetry } from "./machine-telemetry.mapper";

describe("mergeMachineTelemetry", () => {
  const machine = {
    id: "machine-1",
    code: "bin-01",
    deviceId: "esp1",
    name: "SmartBIN Unit #01",
    location: "Lobby",
  };

  it("uses the MongoDB status snapshot with MySQL machine metadata", () => {
    const result = mergeMachineTelemetry(
      [machine],
      [
        {
          deviceId: "esp1",
          kind: "status",
          receivedAt: new Date("2026-10-31T13:00:00.000Z"),
          payload: {
            state: "IDLE",
            compartments: {
              organik_fill_pct: 35,
              anorganik_fill_pct: 60,
              residu_fill_pct: 12,
            },
            sekat_cm: { organik: 48, anorganik: 28, residu: 52 },
          },
        },
      ],
    );

    expect(result[0]).toMatchObject({
      id: "machine-1",
      code: "bin-01",
      name: "SmartBIN Unit #01",
      location: "Lobby",
      status: "IDLE",
      lastSeen: "2026-10-31T13:00:00.000Z",
      organicFill: 35,
      inorganicFill: 60,
      residuFill: 12,
      organicCmLeft: 48,
      inorganicCmLeft: 28,
      residuCmLeft: 52,
    });
  });

  it("returns an offline machine when no MongoDB status snapshot exists", () => {
    const result = mergeMachineTelemetry([machine], []);

    expect(result[0]).toMatchObject({
      id: "machine-1",
      status: "OFFLINE",
      lastSeen: null,
      organicFill: 0,
      inorganicFill: 0,
      residuFill: 0,
    });
  });

  it("ignores non-status snapshots and clamps invalid telemetry values", () => {
    const result = mergeMachineTelemetry(
      [machine],
      [
        {
          deviceId: "esp1",
          kind: "auth",
          receivedAt: new Date(),
          payload: { state: "IDLE" },
        },
        {
          deviceId: "esp1",
          kind: "status",
          receivedAt: new Date("2026-10-31T13:00:00.000Z"),
          payload: {
            state: "UNKNOWN",
            compartments: { organik_fill_pct: 120 },
            sekat_cm: { organik: -1 },
          },
        },
      ],
    );

    expect(result[0]).toMatchObject({
      status: "OFFLINE",
      organicFill: 100,
      inorganicFill: 0,
      organicCmLeft: 0,
    });
  });
});
