import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartbin/core/theme/app_theme.dart';
import 'package:smartbin/data/mock_smartbin_repository.dart';
import 'package:smartbin/data/models.dart';
import 'package:smartbin/features/history/history_screen.dart';
import 'package:smartbin/state/providers.dart';

/// 45 setoran organik dengan paginasi cursor dan statistik seperti server.
class _ServerLikeRepository extends MockSmartbinRepository {
  _ServerLikeRepository() : super(latency: Duration.zero);

  static const total = 45;
  final requestedCursors = <String?>[];

  Deposit _deposit(int i) => Deposit(
    transactionId: 't$i',
    machineId: 'm',
    machineName: 'Unit',
    type: WasteType.organik,
    itemLabel: '',
    weightG: 1000,
    points: 40,
    ratePerKg: 40,
    deviceTime: DateTime.now().subtract(Duration(minutes: i)),
    receivedAt: DateTime.now(),
    status: DepositStatus.credited,
  );

  @override
  Future<DepositPage> depositsPage({WasteType? type, DateTime? from, DateTime? to, String? cursor, int limit = 20}) async {
    requestedCursors.add(cursor);
    if (type != null && type != WasteType.organik) return const DepositPage(items: []);
    final start = int.tryParse(cursor ?? '') ?? 0;
    final end = start + limit < total ? start + limit : total;
    return DepositPage(items: [for (var i = start; i < end; i++) _deposit(i)], nextCursor: end < total ? '$end' : null);
  }

  @override
  Future<DepositStats> depositStats({DateTime? from, DateTime? to}) async => const DepositStats(
    organik: DepositTypeStats(count: total, weightG: 45000, points: 1800),
    anorganik: DepositTypeStats.zero,
    residu: DepositTypeStats.zero,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('riwayat memuat per halaman dan angka ringkasan berasal dari server', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 12000);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _ServerLikeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs), repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(fontFamily: 'Roboto'),
          locale: const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const HistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Hanya halaman pertama yang diminta, tetapi total dan ringkasan mencakup seluruh 45 transaksi.
    expect(repo.requestedCursors, [null]);
    expect(find.text('Semua (45)'), findsOneWidget);
    expect(find.text('Total 45 transaksi tercatat melalui jaringan IoT SmartBIN'), findsOneWidget);
    expect(find.text('Menampilkan 20 dari 45 transaksi'), findsOneWidget);
    expect(find.text('45 kali pemilahan'), findsOneWidget);
    expect(find.text('+1.800'), findsOneWidget);

    await tester.ensureVisible(find.text('Muat Lebih Banyak Riwayat'));
    await tester.tap(find.text('Muat Lebih Banyak Riwayat'));
    await tester.pumpAndSettle();
    expect(repo.requestedCursors, [null, '20']);
    expect(find.text('Menampilkan 40 dari 45 transaksi'), findsOneWidget);

    await tester.ensureVisible(find.text('Muat Lebih Banyak Riwayat'));
    await tester.tap(find.text('Muat Lebih Banyak Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Menampilkan 45 dari 45 transaksi'), findsOneWidget);
    expect(find.text('Muat Lebih Banyak Riwayat'), findsNothing, reason: 'tombol hilang setelah halaman terakhir');
  });

  testWidgets('mengganti jenis sampah meminta ulang dari server, bukan menyaring daftar parsial', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 12000);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _ServerLikeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs), repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(fontFamily: 'Roboto'),
          locale: const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const HistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.requestedCursors, hasLength(1));

    await tester.ensureVisible(find.text('Residu (0)'));
    await tester.tap(find.text('Residu (0)'));
    await tester.pumpAndSettle();

    expect(repo.requestedCursors, hasLength(2), reason: 'filter jenis diteruskan ke server');
    expect(find.text('Belum ada setoran'), findsOneWidget);
  });
}
