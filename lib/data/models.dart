enum UserRole { user, admin }

enum WasteType {
  organik('Organik'),
  anorganik('Anorganik');

  const WasteType(this.label);
  final String label;
}

/// HELD = setoran dari KTP yang belum tertaut; CREDITED = sudah masuk saldo.
enum DepositStatus { held, credited }

enum MachineStatus {
  siap('Siap'),
  penuh('Penuh'),
  gangguan('Gangguan'),
  offline('Offline');

  const MachineStatus(this.label);
  final String label;
}

enum NotificationKind { deposit, card, sync, achievement, machine }

class AdminUserSummary {
  const AdminUserSummary({required this.id, required this.name, required this.email, required this.role, required this.active});
  final String id;
  final String name;
  final String email;
  final String role;
  final bool active;
}

class AdminHistoryRecord {
  const AdminHistoryRecord({
    required this.id,
    required this.userId,
    required this.machine,
    required this.type,
    required this.weightKg,
    required this.points,
    required this.time,
  });
  final String id;
  final String userId;
  final String machine;
  final String type;
  final double weightKg;
  final int points;
  final DateTime time;
}

class CardLink {
  const CardLink({required this.linkedAt, required this.uidHashSuffix});
  final DateTime linkedAt;

  /// Hanya potongan akhir hash HMAC untuk ditampilkan; UID mentah tidak pernah disimpan.
  final String uidHashSuffix;
}

class AppUser {
  const AppUser({
    required this.id,
    this.nim,
    required this.name,
    required this.email,
    required this.role,
    this.faculty = 'Pengguna SmartBIN',
    this.card,
  });

  final String id;

  /// Identitas lama dipertahankan untuk kompatibilitas data terdahulu.
  final String? nim;
  final String name;
  final String email;
  final UserRole role;
  final String faculty;
  final CardLink? card;

  bool get isCardLinked => card != null;
  String get firstName => name.split(' ').firstWhere((s) => s.length > 2, orElse: () => name.split(' ').first);
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.length == 1 ? parts.first[0].toUpperCase() : (parts.first[0] + parts.last[0]).toUpperCase();
  }

  AppUser copyWith({String? name, CardLink? card, bool clearCard = false}) =>
      AppUser(id: id, nim: nim, name: name ?? this.name, email: email, role: role, faculty: faculty, card: clearCard ? null : (card ?? this.card));
}

class Deposit {
  const Deposit({
    required this.transactionId,
    required this.machineId,
    required this.machineName,
    required this.type,
    required this.itemLabel,
    required this.weightG,
    required this.points,
    required this.ratePerKg,
    required this.deviceTime,
    required this.receivedAt,
    required this.status,
  });

  final String transactionId;
  final String machineId;
  final String machineName;
  final WasteType type;
  final String itemLabel;
  final int weightG;
  final int points;
  final int ratePerKg;

  /// Waktu dari RTC mesin (DS3231) — ditampilkan sebagai waktu setoran.
  final DateTime deviceTime;
  final DateTime receivedAt;
  final DepositStatus status;

  bool get isHeld => status == DepositStatus.held;

  /// Selisih besar menandakan mesin sempat offline.
  bool get wasDelayed => receivedAt.difference(deviceTime) > const Duration(minutes: 5);

  Deposit credited() => Deposit(
    transactionId: transactionId,
    machineId: machineId,
    machineName: machineName,
    type: type,
    itemLabel: itemLabel,
    weightG: weightG,
    points: points,
    ratePerKg: ratePerKg,
    deviceTime: deviceTime,
    receivedAt: receivedAt,
    status: DepositStatus.credited,
  );
}

class PointsSummary {
  const PointsSummary({
    required this.balance,
    required this.heldPoints,
    required this.heldDeposits,
    required this.month,
    required this.organicG,
    required this.inorganicG,
    required this.organicCount,
    required this.inorganicCount,
    required this.organicPoints,
    required this.inorganicPoints,
    required this.updatedAt,
  });

  final int balance;
  final int heldPoints;
  final int heldDeposits;
  final DateTime month;
  final int organicG;
  final int inorganicG;
  final int organicCount;
  final int inorganicCount;
  final int organicPoints;
  final int inorganicPoints;
  final DateTime updatedAt;

  int get depositCount => organicCount + inorganicCount;
  int get level => 1 + balance ~/ 1000;
}

class Rates {
  const Rates({required this.organikPerKg, required this.anorganikPerKg, required this.updatedAt});
  final int organikPerKg;
  final int anorganikPerKg;
  final DateTime updatedAt;

  int forType(WasteType t) => t == WasteType.organik ? organikPerKg : anorganikPerKg;
}

class MachineModule {
  const MachineModule({required this.name, required this.detail, required this.ok});
  final String name;
  final String detail;
  final bool ok;
}

class Machine {
  const Machine({
    required this.id,
    required this.name,
    required this.campus,
    required this.location,
    required this.status,
    required this.lastSeen,
    required this.organicFill,
    required this.inorganicFill,
    required this.organicCmLeft,
    required this.inorganicCmLeft,
    required this.temperatureC,
    required this.modules,
  });

  final String id;
  final String name;
  final String campus;
  final String location;
  final MachineStatus status;
  final DateTime lastSeen;

  /// Persentase isi tong 0–100 (sensor ultrasonik).
  final int organicFill;
  final int inorganicFill;
  final int organicCmLeft;
  final int inorganicCmLeft;
  final int temperatureC;
  final List<MachineModule> modules;
}

class TelemetryLog {
  const TelemetryLog({required this.title, required this.detail, required this.time, required this.kind});
  final String title;
  final String detail;
  final DateTime time;
  final String kind; // 'rfid' | 'servo' | 'heartbeat'
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.tag,
    this.depositId,
    this.points,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String? tag;
  final String? depositId;
  final int? points;

  AppNotification markRead() =>
      AppNotification(id: id, kind: kind, title: title, body: body, createdAt: createdAt, read: true, tag: tag, depositId: depositId, points: points);
}

class LinkResult {
  const LinkResult({required this.creditedPoints, required this.creditedDeposits});
  final int creditedPoints;
  final int creditedDeposits;
}

/// Galat yang aman ditampilkan ke pengguna (tidak ada pesan teknis mentah).
class AppException implements Exception {
  const AppException(this.message, {this.field});
  final String message;
  final String? field;
  @override
  String toString() => message;
}
