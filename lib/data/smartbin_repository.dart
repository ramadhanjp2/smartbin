import 'dart:typed_data';

import 'models.dart';

/// Kontrak lapisan data. Layar tidak pernah memanggil API langsung;
/// implementasi REST (`/api/v1`) cukup mengganti [MockSmartbinRepository].
abstract class SmartbinRepository {
  // Akun
  Future<AppUser?> restoreSession();
  Future<AppUser> login({required String identifier, required String password, required bool asAdmin});
  Future<AppUser> register({required String nik, required String name, required String email, required String password});
  Future<void> logout();
  Future<AppUser> me();
  Future<AppUser> updateName(String name);
  Future<void> changePassword({required String oldPassword, required String newPassword});

  // KTP
  /// UID kartu dari NFC dikirim sekali ke `/cards/link`; tidak disimpan di ponsel.
  Future<LinkResult> linkCard(String uid);
  Future<void> unlinkCard(String password);

  // Poin & riwayat
  Future<PointsSummary> pointsSummary();
  Future<List<Deposit>> deposits({WasteType? type});

  /// Beberapa setoran terbaru saja (satu request), untuk Beranda.
  Future<List<Deposit>> recentDeposits({int limit = 3});

  /// Satu halaman riwayat (cursor dari server). [from]/[to] adalah batas waktu absolut (inklusif).
  Future<DepositPage> depositsPage({WasteType? type, DateTime? from, DateTime? to, String? cursor, int limit = 20});

  /// Jumlah, berat, dan poin per jenis untuk seluruh riwayat pada rentang waktu tersebut.
  Future<DepositStats> depositStats({DateTime? from, DateTime? to});
  Future<Deposit> deposit(String transactionId);
  Future<Uint8List?> capturePhoto(String transactionId);
  Future<Rates> rates();

  // Mesin
  Future<List<Machine>> machines();
  Future<List<TelemetryLog>> telemetry(String machineId);

  /// Memberi sinyal setiap kali status mesin berubah (SSE); koneksi dibuka saat ada pendengar dan ditutup saat dibatalkan.
  Stream<void> machineStatusEvents();

  // Notifikasi
  Future<List<AppNotification>> notifications();
  Future<void> markNotificationRead(String id);
  Future<void> markAllNotificationsRead();

  // Admin
  Future<Rates> updateRates({required int organikPerKg, required int anorganikPerKg});
  Future<void> resetMachine(String machineId);
  Future<void> configureMachine(String machineId, {required String name, required String location});
  Future<List<AdminUserSummary>> adminUsers();
  Future<void> createAdminUser({required String nik, required String name, required String email, required String password, required String role});
  Future<void> updateAdminUser(String id, {String? name, String? email, String? role, String? password, bool? active});
  Future<void> deleteAdminUser(String id);
  Future<List<AdminHistoryRecord>> adminHistory();
  Future<AdminHistoryPage> adminHistoryPage({String? cursor, int limit = 50});
  Future<List<DailyWeight>> adminDailyWeights({int days = 7});
}
