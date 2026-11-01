import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartbin/core/theme/app_theme.dart';
import 'package:smartbin/data/mock_smartbin_repository.dart';
import 'package:smartbin/data/models.dart';
import 'package:smartbin/features/admin/admin_management_screen.dart';
import 'package:smartbin/state/providers.dart';

/// 120 baris riwayat admin dengan paginasi cursor seperti server.
class _AdminRepository extends MockSmartbinRepository {
  _AdminRepository() : super(latency: Duration.zero);

  static const total = 120;
  final requestedCursors = <String?>[];

  @override
  Future<AdminHistoryPage> adminHistoryPage({String? cursor, int limit = 50}) async {
    requestedCursors.add(cursor);
    final start = int.tryParse(cursor ?? '') ?? 0;
    final end = start + limit < total ? start + limit : total;
    return AdminHistoryPage(
      items: [
        for (var i = start; i < end; i++)
          AdminHistoryRecord(
            id: 't$i',
            userId: 'u$i',
            userName: 'Pengguna $i',
            machine: 'Unit #01',
            type: 'Organik',
            weightKg: 1,
            points: 40,
            time: DateTime.now().subtract(Duration(minutes: i)),
          ),
      ],
      nextCursor: end < total ? '$end' : null,
    );
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('riwayat admin dimuat per halaman dan memberi tahu cakupan pencarian', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 20000);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _AdminRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          repositoryProvider.overrideWithValue(repo),
          machinesRefreshIntervalProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          theme: AppTheme.light(fontFamily: 'Roboto'),
          locale: const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const AdminManagementScreen(initialTab: 3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.requestedCursors, [null], reason: 'hanya halaman pertama yang diminta');
    expect(find.text('Pencarian dan ekspor CSV mencakup 50 baris yang sudah dimuat.'), findsOneWidget);

    await tester.ensureVisible(find.text('Muat Lebih Banyak'));
    await tester.tap(find.text('Muat Lebih Banyak'));
    await tester.pumpAndSettle();
    expect(repo.requestedCursors, [null, '50']);
    expect(find.text('Pencarian dan ekspor CSV mencakup 100 baris yang sudah dimuat.'), findsOneWidget);

    await tester.ensureVisible(find.text('Muat Lebih Banyak'));
    await tester.tap(find.text('Muat Lebih Banyak'));
    await tester.pumpAndSettle();
    expect(repo.requestedCursors, [null, '50', '100']);
    expect(find.text('Muat Lebih Banyak'), findsNothing, reason: 'tombol hilang di halaman terakhir');
    expect(find.textContaining('baris yang sudah dimuat'), findsNothing, reason: 'semua data sudah termuat');
  });

  testWidgets('tab ringkasan tidak memuat riwayat admin', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _AdminRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          repositoryProvider.overrideWithValue(repo),
          machinesRefreshIntervalProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          theme: AppTheme.light(fontFamily: 'Roboto'),
          locale: const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const AdminManagementScreen(initialTab: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1)); // timer jeda buatan di mock

    expect(repo.requestedCursors, isEmpty);
  });
}
