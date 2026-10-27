import 'dart:math';

import 'models.dart';
import 'smartbin_repository.dart';

/// Flavor `mock`: data palsu di memori dengan jeda jaringan buatan,
/// supaya pengembangan Flutter tidak menunggu backend dan mesin.
///
/// Akun demo:
/// - Pengguna demo: NIK `1234567890123456` atau `ramadhan@example.com`, sandi `smartbin123`
/// - Admin: `admin@smartbin.id`, sandi `admin1234`
class MockSmartbinRepository implements SmartbinRepository {
  MockSmartbinRepository({this.latency = const Duration(milliseconds: 700)}) {
    _seed();
  }

  final Duration latency;
  final _rng = Random();

  AppUser? _session;
  int _failedLogins = 0;
  DateTime? _lockedUntil;

  late int _balance;
  late Rates _rates;
  late List<Deposit> _deposits;
  late List<AppNotification> _notifications;
  late List<Machine> _machines;

  final Map<String, ({AppUser user, String password, String? nik})> _accounts = {};

  Future<void> _delay() => Future.delayed(latency + Duration(milliseconds: _rng.nextInt(300)));

  AppUser get _user {
    final u = _session;
    if (u == null) throw const AppException('Sesi berakhir. Silakan masuk kembali.');
    return u;
  }

  void _seed() {
    final now = DateTime.now();
    DateTime ago({int d = 0, int h = 0, int m = 0}) => now.subtract(Duration(days: d, hours: h, minutes: m));

    _accounts['ramadhan@example.com'] = (
      user: const AppUser(
        id: 'u-1',
        nim: '2106728190',
        name: 'Muhammad Alif Ramadhan',
        email: 'ramadhan@example.com',
        role: UserRole.user,
        faculty: 'Pengguna SmartBIN',
      ),
      password: 'smartbin123',
      nik: '1234567890123456',
    );
    _accounts['admin@smartbin.id'] = (
      user: const AppUser(
        id: 'a-1',
        nim: 'ADM-001',
        name: 'Dimas Pratama',
        email: 'admin@smartbin.id',
        role: UserRole.admin,
        faculty: 'Pengelola Mesin · Fasilitas UI',
      ),
      password: 'admin1234',
      nik: null,
    );

    _balance = 1450;
    _rates = Rates(organikPerKg: 40, anorganikPerKg: 100, updatedAt: now);

    var seq = 884129;
    Deposit dep(
      WasteType type,
      String label,
      int grams,
      DateTime t, {
      DepositStatus status = DepositStatus.credited,
      Duration delay = const Duration(seconds: 3),
      String machine = 'bin-01',
    }) {
      final rate = _rates.forType(type);
      final id = 'TX-SB-${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}-${seq--}';
      return Deposit(
        transactionId: id,
        machineId: machine,
        machineName: machine == 'bin-01' ? 'SmartBIN Unit #01 · Perpustakaan Pusat' : 'SmartBIN Unit #02 · Gedung FT',
        type: type,
        itemLabel: label,
        weightG: grams,
        points: grams * rate ~/ 1000,
        ratePerKg: rate,
        deviceTime: t,
        receivedAt: t.add(delay),
        status: status,
      );
    }

    _deposits = [
      dep(WasteType.anorganik, 'Botol Plastik PET', 1200, ago(m: 45)),
      dep(WasteType.organik, 'Sisa Makanan', 950, ago(h: 2, m: 30)),
      dep(WasteType.anorganik, 'Kaleng & Botol', 1800, ago(d: 1, h: 1)),
      dep(WasteType.anorganik, 'Kertas & Kardus', 700, ago(d: 1, h: 4), delay: const Duration(hours: 2, minutes: 12)),
      dep(WasteType.anorganik, 'Kardus & Plastik', 800, ago(d: 2, h: 3), status: DepositStatus.held, machine: 'bin-02'),
      dep(WasteType.anorganik, 'Botol Minuman', 400, ago(d: 2, h: 5), status: DepositStatus.held, machine: 'bin-02'),
      dep(WasteType.organik, 'Sampah Daun / Taman', 2500, ago(d: 4, h: 2)),
      dep(WasteType.organik, 'Kulit Buah', 1350, ago(d: 5, h: 1)),
      dep(WasteType.anorganik, 'Cup Minuman', 650, ago(d: 6, h: 6)),
      dep(WasteType.organik, 'Ampas Kopi', 1600, ago(d: 8, h: 2)),
      dep(WasteType.anorganik, 'Botol Plastik PET', 2400, ago(d: 9, h: 3)),
      dep(WasteType.organik, 'Sisa Makanan', 2000, ago(d: 11, h: 1)),
    ];

    _notifications = [
      AppNotification(
        id: 'n-1',
        kind: NotificationKind.deposit,
        title: 'Setoran Berhasil Diverifikasi! 🎉',
        body: 'Setoran 1,20 kg Botol Plastik PET di SmartBIN Unit #01 berhasil diverifikasi sensor ultrasonik & load cell. Saldo poin langsung ditambahkan.',
        createdAt: ago(m: 44),
        read: false,
        tag: 'Setoran Selesai',
        depositId: _deposits[0].transactionId,
        points: _deposits[0].points,
      ),
      AppNotification(
        id: 'n-2',
        kind: NotificationKind.deposit,
        title: 'Setoran Sisa Makanan Terverifikasi',
        body: 'Bobot timbangan 0,95 kg bahan organik tercatat di SmartBIN. Poin keberlanjutan telah didepositkan.',
        createdAt: ago(h: 2, m: 29),
        read: false,
        depositId: _deposits[1].transactionId,
        points: _deposits[1].points,
      ),
      AppNotification(
        id: 'n-3',
        kind: NotificationKind.sync,
        title: 'Poin Tertahan Telah Disimpan Aman',
        body: 'Ada 2 setoran dari KTP yang belum tertaut ke akun. Tautkan KTP agar 120 poin masuk ke saldo utama.',
        createdAt: ago(d: 2, h: 3),
        read: false,
        tag: 'Tertahan',
      ),
      AppNotification(
        id: 'n-4',
        kind: NotificationKind.achievement,
        title: 'Pencapaian Eco Warrior Level 2! 🌱',
        body: 'Selamat! Total pemilahan sampah Anda melampaui 10 kg bulan ini.',
        createdAt: ago(d: 4),
        read: true,
        tag: 'Lencana',
      ),
    ];

    _machines = [
      Machine(
        id: 'bin-01',
        name: 'SmartBIN Unit #01',
        campus: 'Kampus Utama',
        location: 'Lantai 1 Lobby Barat, Perpustakaan Pusat',
        status: MachineStatus.siap,
        lastSeen: ago(m: 0).subtract(const Duration(seconds: 10)),
        organicFill: 35,
        inorganicFill: 60,
        organicCmLeft: 48,
        inorganicCmLeft: 28,
        temperatureC: 26,
        modules: const [
          MachineModule(name: 'MQTT Broker', detail: 'Aktif (24ms)', ok: true),
          MachineModule(name: 'Reader RFID', detail: 'Siap Pindai', ok: true),
          MachineModule(name: 'RTC DS3231', detail: 'Tersinkronisasi', ok: true),
          MachineModule(name: 'Dual Load Cell', detail: 'Terkalibrasi', ok: true),
        ],
      ),
      Machine(
        id: 'bin-02',
        name: 'SmartBIN Unit #02',
        campus: 'Fakultas Teknik',
        location: 'Selasar Gedung K, dekat Kantin Teknik',
        status: MachineStatus.penuh,
        lastSeen: ago(m: 1),
        organicFill: 52,
        inorganicFill: 97,
        organicCmLeft: 31,
        inorganicCmLeft: 2,
        temperatureC: 29,
        modules: const [
          MachineModule(name: 'MQTT Broker', detail: 'Aktif (31ms)', ok: true),
          MachineModule(name: 'Reader RFID', detail: 'Siap Pindai', ok: true),
          MachineModule(name: 'RTC DS3231', detail: 'Tersinkronisasi', ok: true),
          MachineModule(name: 'Dual Load Cell', detail: 'Terkalibrasi', ok: true),
        ],
      ),
      Machine(
        id: 'bin-04',
        name: 'SmartBIN Unit #04',
        campus: 'Asrama Mahasiswa',
        location: 'Lobi Gedung C Asrama UI',
        status: MachineStatus.gangguan,
        lastSeen: ago(m: 2),
        organicFill: 41,
        inorganicFill: 38,
        organicCmLeft: 40,
        inorganicCmLeft: 44,
        temperatureC: 27,
        modules: const [
          MachineModule(name: 'MQTT Broker', detail: 'Aktif (40ms)', ok: true),
          MachineModule(name: 'Reader RFID', detail: 'Siap Pindai', ok: true),
          MachineModule(name: 'Motor Servo', detail: 'Macet di 45°', ok: false),
          MachineModule(name: 'Dual Load Cell', detail: 'Terkalibrasi', ok: true),
        ],
      ),
      Machine(
        id: 'bin-03',
        name: 'SmartBIN Unit #03',
        campus: 'FISIP',
        location: 'Lobi Gedung B FISIP',
        status: MachineStatus.offline,
        lastSeen: ago(h: 3, m: 12),
        organicFill: 18,
        inorganicFill: 24,
        organicCmLeft: 61,
        inorganicCmLeft: 57,
        temperatureC: 0,
        modules: const [
          MachineModule(name: 'MQTT Broker', detail: 'Terputus', ok: false),
          MachineModule(name: 'Reader RFID', detail: 'Tidak diketahui', ok: false),
          MachineModule(name: 'RTC DS3231', detail: 'Tidak diketahui', ok: false),
          MachineModule(name: 'Dual Load Cell', detail: 'Tidak diketahui', ok: false),
        ],
      ),
    ];
  }

  // ---------------- Akun ----------------

  @override
  Future<AppUser?> restoreSession() async => _session;

  @override
  Future<AppUser> login({required String identifier, required String password, required bool asAdmin}) async {
    await _delay();
    final lockedUntil = _lockedUntil;
    if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
      final left = lockedUntil.difference(DateTime.now());
      throw AppException('Akun terkunci sementara. Coba lagi dalam ${left.inMinutes + 1} menit.');
    }
    final id = identifier.trim().toLowerCase();
    final match =
        _accounts.values.where((a) => a.user.nim?.toLowerCase() == id || a.user.email.toLowerCase() == id || a.nik == id).firstOrNull ??
        (id == 'admin' ? _accounts['admin@smartbin.id'] : null);
    if (match == null || match.password != password) {
      _failedLogins++;
      if (_failedLogins >= 5) {
        _lockedUntil = DateTime.now().add(const Duration(minutes: 5));
        _failedLogins = 0;
        throw const AppException('5 kali gagal berturut-turut. Login dikunci selama 5 menit.');
      }
      throw AppException('NIK/email atau kata sandi salah. Tersisa ${5 - _failedLogins}x percobaan.');
    }
    if (asAdmin && match.user.role != UserRole.admin) {
      throw const AppException('Akun ini tidak memiliki akses Admin / Teknisi.');
    }
    _failedLogins = 0;
    return _session = match.user;
  }

  int get remainingLoginAttempts => 5 - _failedLogins;

  @override
  Future<AppUser> register({required String nik, required String name, required String email, required String password}) async {
    await _delay();
    final normalizedNik = nik.trim();
    final normalizedEmail = email.trim().toLowerCase();
    if (!RegExp(r'^\d{16}$').hasMatch(normalizedNik)) {
      throw const AppException('NIK harus terdiri dari 16 angka.', field: 'nik');
    }
    if (!RegExp(r'^[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}$').hasMatch(normalizedEmail)) {
      throw const AppException('Masukkan alamat email yang valid.', field: 'email');
    }
    if (_accounts.values.any((a) => a.nik == normalizedNik)) {
      throw const AppException('NIK sudah terdaftar. Silakan masuk dengan akun tersebut.', field: 'nik');
    }
    if (_accounts.values.any((a) => a.user.email.toLowerCase() == normalizedEmail)) {
      throw const AppException('Email sudah dipakai akun lain.', field: 'email');
    }
    final user = AppUser(id: 'u-${_accounts.length + 1}', name: name, email: normalizedEmail, role: UserRole.user);
    _accounts[normalizedEmail] = (user: user, password: password, nik: normalizedNik);
    // Akun baru: saldo kosong, tetapi mesin mungkin sudah mencatat setoran dari KTP ini (tertahan).
    _balance = 0;
    _deposits = _deposits.where((d) => d.isHeld).toList();
    _notifications = [];
    return _session = user;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _session = null;
  }

  @override
  Future<AppUser> me() async {
    await _delay();
    return _user;
  }

  @override
  Future<AppUser> updateName(String name) async {
    await _delay();
    final updated = _user.copyWith(name: name);
    final account = _accounts[_accountKey(updated)]!;
    _accounts[_accountKey(updated)] = (user: updated, password: account.password, nik: account.nik);
    return _session = updated;
  }

  @override
  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    await _delay();
    final key = _accountKey(_user);
    if (_accounts[key]!.password != oldPassword) {
      throw const AppException('Kata sandi lama tidak sesuai.', field: 'old');
    }
    _accounts[key] = (user: _user, password: newPassword, nik: _accounts[key]!.nik);
  }

  String _accountKey(AppUser u) => u.email;

  // ---------------- KTP ----------------

  @override
  Future<LinkResult> linkCard(String uid) async {
    await _delay();
    if (_user.isCardLinked) throw const AppException('Akun ini sudah memiliki KTP tertaut.');
    if (uid.toUpperCase().startsWith('04DEAD')) {
      throw const AppException('KTP sudah tertaut ke akun lain.');
    }
    final held = _deposits.where((d) => d.isHeld).toList();
    final pts = held.fold<int>(0, (s, d) => s + d.points);
    _deposits = [for (final d in _deposits) d.isHeld ? d.credited() : d];
    _balance += pts;
    final hash = List.generate(4, (_) => _rng.nextInt(16).toRadixString(16)).join().toUpperCase();
    final updated = _user.copyWith(
      card: CardLink(linkedAt: DateTime.now(), uidHashSuffix: hash),
    );
    final account = _accounts[_accountKey(updated)]!;
    _accounts[_accountKey(updated)] = (user: updated, password: account.password, nik: account.nik);
    _session = updated;
    _notifications = [
      AppNotification(
        id: 'n-${DateTime.now().millisecondsSinceEpoch}',
        kind: NotificationKind.card,
        title: 'KTP Berhasil Ditautkan!',
        body: pts > 0
            ? 'Kartu KTP Anda kini tertaut. +$pts poin dari ${held.length} setoran tertahan dimasukkan ke saldo.'
            : 'Kartu KTP Anda kini tertaut dan siap dipakai di semua mesin SmartBIN.',
        createdAt: DateTime.now(),
        read: false,
        tag: 'KTP Aktif',
      ),
      ..._notifications,
    ];
    return LinkResult(creditedPoints: pts, creditedDeposits: held.length);
  }

  @override
  Future<void> unlinkCard(String password) async {
    await _delay();
    final key = _accountKey(_user);
    if (_accounts[key]!.password != password) {
      throw const AppException('Kata sandi tidak sesuai.', field: 'password');
    }
    final updated = _user.copyWith(clearCard: true);
    _accounts[key] = (user: updated, password: password, nik: _accounts[key]!.nik);
    _session = updated;
  }

  // ---------------- Poin & riwayat ----------------

  @override
  Future<PointsSummary> pointsSummary() async {
    await _delay();
    _user;
    final now = DateTime.now();
    final month = _deposits.where((d) => d.deviceTime.year == now.year && d.deviceTime.month == now.month);
    final org = month.where((d) => d.type == WasteType.organik);
    final ano = month.where((d) => d.type == WasteType.anorganik);
    final held = _deposits.where((d) => d.isHeld);
    int sumG(Iterable<Deposit> l) => l.fold(0, (s, d) => s + d.weightG);
    int sumP(Iterable<Deposit> l) => l.fold(0, (s, d) => s + d.points);
    return PointsSummary(
      balance: _balance,
      heldPoints: sumP(held),
      heldDeposits: held.length,
      month: now,
      organicG: sumG(org),
      inorganicG: sumG(ano),
      organicCount: org.length,
      inorganicCount: ano.length,
      organicPoints: sumP(org.where((d) => !d.isHeld)),
      inorganicPoints: sumP(ano.where((d) => !d.isHeld)),
      updatedAt: now,
    );
  }

  @override
  Future<List<Deposit>> deposits({WasteType? type}) async {
    await _delay();
    _user;
    final list = type == null ? _deposits : _deposits.where((d) => d.type == type);
    return List.of(list)..sort((a, b) => b.deviceTime.compareTo(a.deviceTime));
  }

  @override
  Future<Deposit> deposit(String transactionId) async {
    await _delay();
    return _deposits.firstWhere((d) => d.transactionId == transactionId, orElse: () => throw const AppException('Setoran tidak ditemukan.'));
  }

  @override
  Future<Rates> rates() async {
    await _delay();
    return _rates;
  }

  // ---------------- Mesin ----------------

  @override
  Future<List<Machine>> machines() async {
    await _delay();
    return List.of(_machines);
  }

  @override
  Future<List<TelemetryLog>> telemetry(String machineId) async {
    await _delay();
    final now = DateTime.now();
    return [
      TelemetryLog(
        title: 'KTP ID berhasil diverifikasi',
        detail: '1 Botol Plastik +50 Poin terkreditasi',
        time: now.subtract(const Duration(seconds: 8)),
        kind: 'rfid',
      ),
      TelemetryLog(
        title: 'Servo Diputar ke Anorganik',
        detail: 'Induktif Proximity Sensor trigger',
        time: now.subtract(const Duration(seconds: 14)),
        kind: 'servo',
      ),
      TelemetryLog(
        title: 'Heartbeat Telemetry Ack',
        detail: 'Payload: {batt: 100%, sig: -64dBm}',
        time: now.subtract(const Duration(seconds: 26)),
        kind: 'heartbeat',
      ),
    ];
  }

  // ---------------- Notifikasi ----------------

  @override
  Future<List<AppNotification>> notifications() async {
    await _delay();
    return List.of(_notifications);
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _notifications = [for (final n in _notifications) n.id == id ? n.markRead() : n];
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _notifications = [for (final n in _notifications) n.markRead()];
  }

  // ---------------- Admin ----------------

  void _requireAdmin() {
    if (_user.role != UserRole.admin) throw const AppException('Hanya admin yang dapat melakukan aksi ini.');
  }

  @override
  Future<Rates> updateRates({required int organikPerKg, required int anorganikPerKg}) async {
    await _delay();
    _requireAdmin();
    return _rates = Rates(organikPerKg: organikPerKg, anorganikPerKg: anorganikPerKg, updatedAt: DateTime.now());
  }

  @override
  Future<void> resetMachine(String machineId) async {
    await _delay();
    _requireAdmin();
    _machines = [
      for (final m in _machines)
        m.id == machineId && m.status == MachineStatus.gangguan
            ? Machine(
                id: m.id,
                name: m.name,
                campus: m.campus,
                location: m.location,
                status: MachineStatus.siap,
                lastSeen: DateTime.now(),
                organicFill: m.organicFill,
                inorganicFill: m.inorganicFill,
                organicCmLeft: m.organicCmLeft,
                inorganicCmLeft: m.inorganicCmLeft,
                temperatureC: m.temperatureC,
                modules: m.modules,
              )
            : m,
    ];
  }
}
