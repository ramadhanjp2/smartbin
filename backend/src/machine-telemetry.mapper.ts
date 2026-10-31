import { Document } from "mongodb";

const MACHINE_STATUSES = new Set([
  "IDLE",
  "SIBUK",
  "SIAP",
  "PENUH",
  "GANGGUAN",
  "OFFLINE",
]);

function objectValue(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null
    ? (value as Record<string, unknown>)
    : {};
}

function percentage(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(100, Math.round(value)));
}

function distance(value: unknown): number {
  if (
    typeof value !== "number" ||
    !Number.isInteger(value) ||
    value < 0 ||
    value > 65_535
  )
    return 0;
  return value;
}

function timestamp(value: unknown): string | null {
  if (value instanceof Date && !Number.isNaN(value.getTime()))
    return value.toISOString();
  if (typeof value === "string" && !Number.isNaN(Date.parse(value)))
    return new Date(value).toISOString();
  return null;
}

export function mergeMachineTelemetry(
  machines: Record<string, unknown>[],
  snapshots: Document[],
): Record<string, unknown>[] {
  const snapshotsByDevice = new Map(
    snapshots
      .filter((snapshot) => snapshot.kind === "status")
      .map((snapshot) => [snapshot.deviceId, snapshot]),
  );

  return machines.map((machine) => {
    const snapshot =
      typeof machine.deviceId === "string"
        ? snapshotsByDevice.get(machine.deviceId)
        : undefined;
    if (!snapshot) {
      return {
        ...machine,
        status: "OFFLINE",
        lastSeen: null,
        organicFill: 0,
        inorganicFill: 0,
        residuFill: 0,
        organicCmLeft: 0,
        inorganicCmLeft: 0,
        residuCmLeft: 0,
      };
    }

    const payload = objectValue(snapshot.payload);
    const compartments = objectValue(payload.compartments);
    const distances = objectValue(payload.sekat_cm);
    const state = payload.state;

    return {
      ...machine,
      status:
        typeof state === "string" && MACHINE_STATUSES.has(state)
          ? state
          : "OFFLINE",
      lastSeen: timestamp(snapshot.receivedAt),
      organicFill: percentage(compartments.organik_fill_pct),
      inorganicFill: percentage(compartments.anorganik_fill_pct),
      residuFill: percentage(compartments.residu_fill_pct),
      organicCmLeft: distance(distances.organik),
      inorganicCmLeft: distance(distances.anorganik),
      residuCmLeft: distance(distances.residu),
    };
  });
}
