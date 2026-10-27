import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_smartbin_repository.dart';
import '../data/mock_smartbin_repository.dart';
import '../data/models.dart';
import '../data/nfc_reader.dart';
import '../data/smartbin_repository.dart';

/// Di-override di `main()` setelah SharedPreferences siap.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final apiHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

const _useMockRepository = bool.fromEnvironment('SMARTBIN_USE_MOCK', defaultValue: false);
const _apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: defaultSmartbinApiUrl);

final repositoryProvider = Provider<SmartbinRepository>((ref) {
  if (_useMockRepository) return MockSmartbinRepository();
  return ApiSmartbinRepository(baseUrl: _apiBaseUrl, client: ref.watch(apiHttpClientProvider), secureStorage: ref.watch(secureStorageProvider));
});

final nfcReaderProvider = Provider<NfcReader>((ref) => MockNfcReader());

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

class NotificationSoundController extends Notifier<bool> {
  static const _key = 'notif_sound';

  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(_key) ?? true;

  void set(bool v) {
    state = v;
    ref.read(sharedPrefsProvider).setBool(_key, v);
  }
}

final notificationSoundProvider = NotifierProvider<NotificationSoundController, bool>(NotificationSoundController.new);

// ---------------- Sesi ----------------

class AuthState {
  const AuthState({this.user, this.needsCardSetup = false});
  final AppUser? user;

  /// True tepat setelah registrasi: pengguna diarahkan ke layar Tautkan KTM.
  final bool needsCardSetup;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  SmartbinRepository get _repo => ref.read(repositoryProvider);

  Future<void> login(String identifier, String password, {required bool asAdmin}) async {
    final user = await _repo.login(identifier: identifier, password: password, asAdmin: asAdmin);
    state = AuthState(user: user);
  }

  Future<void> restoreSession() async {
    final user = await _repo.restoreSession();
    if (user != null) state = AuthState(user: user);
  }

  Future<void> register({required String nim, required String name, required String email, required String password}) async {
    final user = await _repo.register(nim: nim, name: name, email: email, password: password);
    _invalidateUserData();
    state = AuthState(user: user, needsCardSetup: true);
  }

  void finishCardSetup() => state = AuthState(user: state.user);

  void setUser(AppUser user) => state = AuthState(user: user, needsCardSetup: state.needsCardSetup);

  Future<void> logout() async {
    try {
      await _repo.logout();
    } finally {
      _invalidateUserData();
      state = const AuthState();
    }
  }

  /// Cache data pengguna dibersihkan saat logout / ganti akun (FR-AUTH-04).
  void _invalidateUserData() {
    ref.invalidate(pointsSummaryProvider);
    ref.invalidate(depositsProvider);
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

final depositDetailProvider = FutureProvider.family<Deposit, String>((ref, id) => ref.watch(repositoryProvider).deposit(id));

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

final machinesProvider = FutureProvider<List<Machine>>((ref) => ref.watch(repositoryProvider).machines());

final telemetryProvider = FutureProvider.family<List<TelemetryLog>, String>((ref, id) => ref.watch(repositoryProvider).telemetry(id));

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) => ref.watch(repositoryProvider).notifications());

final unreadCountProvider = Provider<int>((ref) => ref.watch(notificationsProvider).value?.where((n) => !n.read).length ?? 0);
