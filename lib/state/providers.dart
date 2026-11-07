import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/router/app_router.dart';
import '../data/api_smartbin_repository.dart';
import '../data/mock_smartbin_repository.dart';
import '../data/models.dart';
import '../data/nfc_reader.dart';
import '../data/push_notification_service.dart';
import '../data/smartbin_repository.dart';

/// Di-override di `main()` setelah SharedPreferences siap.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final apiHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

const useMockRepository = bool.fromEnvironment('SMARTBIN_USE_MOCK', defaultValue: false);
const _apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: defaultSmartbinApiUrl);

final repositoryProvider = Provider<SmartbinRepository>((ref) {
  if (useMockRepository) return MockSmartbinRepository();
  return ApiSmartbinRepository(baseUrl: _apiBaseUrl, client: ref.watch(apiHttpClientProvider), secureStorage: ref.watch(secureStorageProvider));
});

final nfcReaderProvider = Provider<NfcReader>((ref) => PlatformNfcReader());
final pushNotificationProvider = Provider<PushNotificationService>((ref) {
  final service = PushNotificationService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

// ---------------- Preferensi perangkat ----------------

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final saved = ref.read(sharedPrefsProvider).getString(_key);
    return ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(sharedPrefsProvider).setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class OnboardingController extends Notifier<bool> {
  static const _key = 'onboarding_seen';

  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(_key) ?? false;

  void complete() {
    state = true;
    ref.read(sharedPrefsProvider).setBool(_key, true);
  }
}

final onboardingSeenProvider = NotifierProvider<OnboardingController, bool>(OnboardingController.new);

class NotificationPushController extends Notifier<bool> {
  static const _key = 'notif_sound';

  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(_key) ?? true;

  void set(bool v) {
    state = v;
    ref.read(sharedPrefsProvider).setBool(_key, v);
    unawaited(ref.read(authProvider.notifier).updatePushPreference(v));
  }
}

final notificationPushEnabledProvider = NotifierProvider<NotificationPushController, bool>(NotificationPushController.new);

class NfcEnabledController extends Notifier<bool> {
  static const _key = 'nfc_enabled';

  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(_key) ?? true;

  void set(bool value) {
    state = value;
    ref.read(sharedPrefsProvider).setBool(_key, value);
  }
}

final nfcEnabledProvider = NotifierProvider<NfcEnabledController, bool>(NfcEnabledController.new);

// ---------------- Sesi ----------------

class AuthState {
  const AuthState({this.user, this.needsCardSetup = false});
  final AppUser? user;

  /// True tepat setelah registrasi: pengguna diarahkan untuk menautkan KTP.
  final bool needsCardSetup;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  SmartbinRepository get _repo => ref.read(repositoryProvider);

  Future<void> login(String identifier, String password, {required bool asAdmin}) async {
    final user = await _repo.login(identifier: identifier, password: password, asAdmin: asAdmin);
    state = AuthState(user: user);
    await _syncPushToken();
  }

  Future<void> restoreSession() async {
    final user = await _repo.restoreSession();
    if (user != null) {
      state = AuthState(user: user);
      await _syncPushToken();
    }
  }

  Future<void> register({required String nik, required String name, required String email, required String password}) async {
    final user = await _repo.register(nik: nik, name: name, email: email, password: password);
    _invalidateUserData();
    state = AuthState(user: user, needsCardSetup: true);
    await _syncPushToken();
  }

  void finishCardSetup() => state = AuthState(user: state.user);

  void setUser(AppUser user) => state = AuthState(user: user, needsCardSetup: state.needsCardSetup);

  Future<void> logout() async {
    try {
      await _unregisterPushToken();
      await _repo.logout();
    } finally {
      _invalidateUserData();
      state = const AuthState();
    }
  }

  Future<void> updatePushPreference(bool enabled) async {
    if (enabled) {
      await _syncPushToken();
    } else {
      await _unregisterPushToken();
    }
  }

  Future<void> _syncPushToken() async {
    if (!PushNotificationService.enabled || !ref.read(notificationPushEnabledProvider) || state.user == null) {
      return;
    }
    try {
      final push = ref.read(pushNotificationProvider);
      await push.initialize(
        onToken: (token) async {
          if (state.user != null && ref.read(notificationPushEnabledProvider)) {
            await _repo.registerPushToken(token);
          }
        },
        onOpen: _openPushNotification,
      );
      final token = await push.requestPermissionAndGetToken();
      if (token != null) await _repo.registerPushToken(token);
    } on AppException catch (error) {
      debugPrint('SmartBIN push registration failed: ${error.message}');
    } on PlatformException catch (error) {
      debugPrint('SmartBIN push registration failed: ${error.code}');
    } catch (error) {
      debugPrint('SmartBIN push initialization failed: $error');
    }
  }

  Future<void> _unregisterPushToken() async {
    if (!PushNotificationService.enabled || state.user == null) return;
    try {
      final token = await ref.read(pushNotificationProvider).currentToken();
      if (token != null) await _repo.unregisterPushToken(token);
    } on AppException catch (error) {
      debugPrint('SmartBIN push token removal failed: ${error.message}');
    } on PlatformException catch (error) {
      debugPrint('SmartBIN push token removal failed: ${error.code}');
    } catch (error) {
      debugPrint('SmartBIN push token removal failed: $error');
    }
  }

  void _openPushNotification(Map<String, String> data) {
    ref.invalidate(notificationsProvider);
    final depositId = data['depositId'];
    final router = ref.read(routerProvider);
    if (depositId != null && depositId.isNotEmpty) {
      router.go('/deposit/${Uri.encodeComponent(depositId)}');
    } else {
      router.go('/notifications');
    }
  }

  /// Cache data pengguna dibersihkan saat logout / ganti akun (FR-AUTH-04).
  void _invalidateUserData() {
    ref.invalidate(pointsSummaryProvider);
    ref.invalidate(depositsProvider);
    ref.invalidate(depositHistoryProvider);
    ref.invalidate(depositStatsProvider);
    ref.invalidate(recentDepositsProvider);
    ref.invalidate(notificationsProvider);
  }

  Future<LinkResult> linkCard(String uid) async {
    final result = await _repo.linkCard(uid);
    state = AuthState(user: await _repo.me(), needsCardSetup: state.needsCardSetup);
    _invalidateUserData();
    return result;
  }

  Future<void> unlinkCard(String password) async {
    await _repo.unlinkCard(password);
    state = AuthState(user: await _repo.me());
  }

  Future<void> updateName(String name) async {
    state = AuthState(user: await _repo.updateName(name));
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authProvider).user);

// ---------------- Data ----------------

final pointsSummaryProvider = FutureProvider<PointsSummary>((ref) => ref.watch(repositoryProvider).pointsSummary());

/// `null` = semua jenis.
final depositsProvider = FutureProvider.family<List<Deposit>, WasteType?>((ref, type) => ref.watch(repositoryProvider).deposits(type: type));

/// Hanya beberapa setoran terakhir (Beranda); tidak memuat seluruh riwayat.
final recentDepositsProvider = FutureProvider<List<Deposit>>((ref) => ref.watch(repositoryProvider).recentDeposits());

/// Filter riwayat; record punya kesetaraan nilai sehingga dapat menjadi kunci family.
typedef DepositFilter = ({WasteType? type, DateTime? from, DateTime? to});
typedef DepositRange = ({DateTime? from, DateTime? to});

class DepositHistoryState {
  const DepositHistoryState({required this.items, this.nextCursor, this.loadingMore = false, this.loadMoreError});
  final List<Deposit> items;
  final String? nextCursor;
  final bool loadingMore;

  /// Galat saat memuat halaman berikutnya; daftar yang sudah termuat tetap ditampilkan.
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;
}

/// Riwayat setoran berhalaman dari server (cursor). Halaman berikutnya dimuat lewat [loadMore].
class DepositHistoryController extends AsyncNotifier<DepositHistoryState> {
  DepositHistoryController(this.filter);
  final DepositFilter filter;
  static const pageSize = 20;

  @override
  Future<DepositHistoryState> build() async {
    final page = await ref.watch(repositoryProvider).depositsPage(type: filter.type, from: filter.from, to: filter.to, limit: pageSize);
    return DepositHistoryState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(DepositHistoryState(items: current.items, nextCursor: current.nextCursor, loadingMore: true));
    try {
      final page = await ref
          .read(repositoryProvider)
          .depositsPage(type: filter.type, from: filter.from, to: filter.to, cursor: current.nextCursor, limit: pageSize);
      if (!ref.mounted) return;
      state = AsyncData(DepositHistoryState(items: [...current.items, ...page.items], nextCursor: page.nextCursor));
    } catch (error) {
      if (!ref.mounted) return;
      state = AsyncData(DepositHistoryState(items: current.items, nextCursor: current.nextCursor, loadMoreError: error));
    }
  }
}

final depositHistoryProvider = AsyncNotifierProvider.autoDispose.family<DepositHistoryController, DepositHistoryState, DepositFilter>(
  DepositHistoryController.new,
);

/// Jumlah, berat, dan poin dari seluruh riwayat (bukan hanya halaman termuat).
final depositStatsProvider = FutureProvider.autoDispose.family<DepositStats, DepositRange>(
  (ref, range) => ref.watch(repositoryProvider).depositStats(from: range.from, to: range.to),
);

final depositDetailProvider = FutureProvider.family<Deposit, String>((ref, id) => ref.watch(repositoryProvider).deposit(id));
final capturePhotoProvider = FutureProvider.family<Uint8List?, String>((ref, id) => ref.watch(repositoryProvider).capturePhoto(id));

/// Nilai poin dari API; bila gagal memuat, pakai nilai terakhir yang tersimpan (S12).
final ratesProvider = FutureProvider<Rates>((ref) async {
  final prefs = ref.read(sharedPrefsProvider);
  try {
    final r = await ref.watch(repositoryProvider).rates();
    prefs.setStringList('rates', ['${r.organikPerKg}', '${r.anorganikPerKg}', r.updatedAt.toIso8601String()]);
    return r;
  } catch (_) {
    final saved = prefs.getStringList('rates');
    if (saved == null) rethrow;
    return Rates(organikPerKg: int.parse(saved[0]), anorganikPerKg: int.parse(saved[1]), updatedAt: DateTime.parse(saved[2]));
  }
});

/// Jeda muat ulang berkala sebagai jaring pengaman bila SSE terputus; null mematikannya (mock dan test).
final machinesRefreshIntervalProvider = Provider<Duration?>((ref) => useMockRepository ? null : const Duration(seconds: 60));

/// Sinyal SSE saat status mesin berubah. Nilainya penghitung agar tiap event dianggap berbeda
/// (Riverpod membuang pembaruan yang nilainya sama, sehingga event `void` berulang akan hilang).
final machineEventsProvider = StreamProvider.autoDispose<int>((ref) {
  var tick = 0;
  return ref.watch(repositoryProvider).machineStatusEvents().map((_) => ++tick);
});

/// Diperbarui lewat SSE (+ polling cadangan). autoDispose: koneksi dan timer berhenti saat tidak ada layar yang menampilkannya.
/// Data lama tetap tampil selama muat ulang berjalan.
final machinesProvider = FutureProvider.autoDispose<List<Machine>>((ref) async {
  // Didaftarkan sebelum await pertama agar langganan SSE tidak putus-sambung setiap data dimuat ulang.
  Timer? debounce;
  ref.listen(machineEventsProvider, (_, _) {
    if (debounce?.isActive ?? false) return;
    debounce = Timer(const Duration(seconds: 1), ref.invalidateSelf);
  });
  ref.onDispose(() => debounce?.cancel());
  final machines = await ref.watch(repositoryProvider).machines();
  final interval = ref.watch(machinesRefreshIntervalProvider);
  if (interval != null && ref.mounted) {
    final timer = Timer(interval, ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return machines;
});
final adminUsersProvider = FutureProvider<List<AdminUserSummary>>((ref) => ref.watch(repositoryProvider).adminUsers());

class AdminHistoryState {
  const AdminHistoryState({required this.items, this.nextCursor, this.loadingMore = false, this.loadMoreError});
  final List<AdminHistoryRecord> items;
  final String? nextCursor;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;
}

/// Riwayat admin berhalaman; pencarian dan ekspor CSV hanya mencakup baris yang sudah dimuat.
class AdminHistoryController extends AsyncNotifier<AdminHistoryState> {
  static const pageSize = 50;

  @override
  Future<AdminHistoryState> build() async {
    final page = await ref.watch(repositoryProvider).adminHistoryPage(limit: pageSize);
    return AdminHistoryState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(AdminHistoryState(items: current.items, nextCursor: current.nextCursor, loadingMore: true));
    try {
      final page = await ref.read(repositoryProvider).adminHistoryPage(cursor: current.nextCursor, limit: pageSize);
      if (!ref.mounted) return;
      state = AsyncData(AdminHistoryState(items: [...current.items, ...page.items], nextCursor: page.nextCursor));
    } catch (error) {
      if (!ref.mounted) return;
      state = AsyncData(AdminHistoryState(items: current.items, nextCursor: current.nextCursor, loadMoreError: error));
    }
  }
}

final adminHistoryProvider = AsyncNotifierProvider.autoDispose<AdminHistoryController, AdminHistoryState>(AdminHistoryController.new);

/// Berat per hari (7 hari terakhir, WIB) untuk grafik admin, dihitung di server.
final adminDailyWeightsProvider = FutureProvider.autoDispose<List<DailyWeight>>((ref) => ref.watch(repositoryProvider).adminDailyWeights());

final telemetryProvider = FutureProvider.family<List<TelemetryLog>, String>((ref, id) => ref.watch(repositoryProvider).telemetry(id));

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) => ref.watch(repositoryProvider).notifications());

final unreadCountProvider = Provider<int>((ref) => ref.watch(notificationsProvider).value?.where((n) => !n.read).length ?? 0);
