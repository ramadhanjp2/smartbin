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
  Future<Deposit> deposit(String transactionId);
  Future<Rates> rates();

  // Mesin
  Future<List<Machine>> machines();
  Future<List<TelemetryLog>> telemetry(String machineId);

  // Notifikasi
  Future<List<AppNotification>> notifications();
  Future<void> markNotificationRead(String id);
  Future<void> markAllNotificationsRead();

  // Admin
  Future<Rates> updateRates({required int organikPerKg, required int anorganikPerKg});
  Future<void> resetMachine(String machineId);
  Future<void> configureMachine(String machineId, {required String name, required String location});
  Future<List<AdminUserSummary>> adminUsers();
  Future<List<AdminHistoryRecord>> adminHistory();
}
