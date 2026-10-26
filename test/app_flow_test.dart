import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartbin/core/router/app_router.dart';
import 'package:smartbin/data/mock_smartbin_repository.dart';
import 'package:smartbin/main.dart';
import 'package:smartbin/state/providers.dart';

/// Alur utama dijalankan di atas repository mock. Jalankan dengan
/// `flutter test --update-goldens test/app_flow_test.dart` untuk menyimpan
/// screenshot tiap layar ke `test/goldens/`.
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> bytes(String f) async => ByteData.sublistView(await File('$dir/$f').readAsBytes());
  final roboto = FontLoader('Roboto');
  for (final f in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf']) {
    roboto.addFont(bytes(f));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(bytes('materialicons-regular.otf'))).load();
}

Future<void> _settle(WidgetTester tester, {int frames = 15}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<ProviderContainer> _start(WidgetTester tester, {Size size = const Size(390, 1800), bool onboarded = true}) async {
  tester.view.devicePixelRatio = 1.5;
  tester.view.physicalSize = size * 1.5;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'onboarding_seen': onboarded});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        repositoryProvider.overrideWithValue(MockSmartbinRepository(latency: const Duration(milliseconds: 50))),
      ],
      child: const SmartbinApp(fontFamily: 'Roboto'),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(SmartbinApp)));
}

Future<void> _shot(String name) => expectLater(find.byType(SmartbinApp), matchesGoldenFile('goldens/$name.png'));

Future<void> _login(WidgetTester tester, String id, String pw) async {
  await tester.enterText(find.byType(TextFormField).at(0), id);
  await tester.enterText(find.byType(TextFormField).at(1), pw);
  await tester.tap(find.text('Masuk ke Akun'));
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await _loadFonts();
  });

  testWidgets('onboarding → login → semua tab → tautkan KTM', (tester) async {
    final c = await _start(tester, onboarded: false);
    expect(find.text('Apa itu SmartBIN?'), findsOneWidget);
    await _shot('00_onboarding');
    await tester.tap(find.text('Lewati'));
    await _settle(tester);

    expect(find.text('Selamat Datang!'), findsOneWidget);
    await _shot('01_login');

    await _login(tester, '2106728190', 'salah123');
    expect(find.textContaining('Tersisa 4x'), findsOneWidget);

    await _login(tester, '2106728190', 'smartbin123');
    expect(find.textContaining('Halo, Muhammad'), findsOneWidget);
    expect(find.text('KTM Belum Tertaut!'), findsOneWidget);
    expect(find.text('1.450'), findsOneWidget);
    await _shot('02_beranda');

    await tester.tap(find.text('Riwayat').last);
    await _settle(tester);
    expect(find.text('Riwayat Setoran'), findsOneWidget);
    await _shot('03_riwayat');

    await tester.tap(find.text('Botol Plastik PET').first);
    await _settle(tester);
    expect(find.text('Kalkulasi Formula Poin'), findsOneWidget);
    expect(find.text('= 120 Poin'), findsOneWidget);
    await _shot('04_detail_setoran');
    c.read(routerProvider).pop();
    await _settle(tester);

    await tester.tap(find.text('Mesin').last);
    await _settle(tester);
    expect(find.text('Status Mesin SmartBIN'), findsOneWidget);
    await _shot('05_mesin');

    await tester.tap(find.text('Profil').last);
    await _settle(tester);
    expect(find.text('Muhammad Alif Ramadhan'), findsWidgets);
    await _shot('06_profil');

    await tester.tap(find.byTooltip('Notifikasi, 3 belum dibaca'));
    await _settle(tester);
    expect(find.text('3 Belum Dibaca'), findsOneWidget);
    await _shot('07_notifikasi');
    c.read(routerProvider).pop();
    await _settle(tester);

    c.read(routerProvider).push('/rates');
    await _settle(tester);
    expect(find.text('Panduan Memilah Sampah'), findsOneWidget);
    await _shot('08_nilai_poin');
    c.read(routerProvider).pop();
    await _settle(tester);

    await tester.tap(find.text('Beranda').last);
    await _settle(tester);
    await tester.tap(find.text('Tautkan Sekarang'));
    await _settle(tester);
    expect(find.text('Tautkan KTM Mahasiswa'), findsOneWidget);
    await _shot('09_tautkan_ktm');

    await tester.tap(find.text('Mulai Pindai NFC'));
    await _settle(tester, frames: 40);
    expect(find.text('KTM Berhasil Ditautkan!'), findsOneWidget);
    expect(find.textContaining('+120 poin dari 2 setoran'), findsOneWidget);
    await _shot('10_ktm_sukses');

    await tester.tap(find.text('Lanjut ke Beranda'));
    await _settle(tester);
    expect(find.text('KTM Belum Tertaut!'), findsNothing);
    expect(find.text('1.570'), findsOneWidget);
  });

  testWidgets('registrasi baru diarahkan ke Tautkan KTM langkah 2', (tester) async {
    await _start(tester);
    await tester.tap(find.text('Daftar Sekarang'));
    await _settle(tester);
    await _shot('11_registrasi');

    await tester.tap(find.text('Daftar Sekarang'));
    await _settle(tester);
    expect(find.text('NIM wajib diisi'), findsOneWidget);
    expect(find.text('Anda harus menyetujui kebijakan privasi'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'E32253079');
    await tester.enterText(fields.at(1), 'Rina Lestari');
    await tester.enterText(fields.at(2), 'rina@student.polije.ac.id');
    await tester.enterText(fields.at(3), 'hijau2026');
    await tester.enterText(fields.at(4), 'hijau2026');
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('Daftar Sekarang'));
    await _settle(tester);
    expect(find.text('Langkah 2 dari 2'), findsOneWidget);

    await tester.tap(find.text('Lewati Sementara'));
    await _settle(tester);
    expect(find.textContaining('Halo, Rina'), findsOneWidget);
  });

  testWidgets('admin masuk ke dashboard mesin', (tester) async {
    await _start(tester, size: const Size(390, 2600));
    await tester.tap(find.text('Admin / Teknisi'));
    await _settle(tester, frames: 3);
    await _login(tester, 'admin@smartbin.id', 'admin1234');
    expect(find.text('Dashboard Mesin'), findsOneWidget);
    expect(find.text('Konfigurasi Nilai Poin'), findsOneWidget);
    await _shot('12_admin');
  });

  testWidgets('layar utama tidak overflow di lebar 360dp', (tester) async {
    final c = await _start(tester, size: const Size(360, 740));
    await _login(tester, '2106728190', 'smartbin123');
    for (final route in ['/home', '/history', '/machines', '/profile', '/notifications', '/link-ktm', '/rates']) {
      c.read(routerProvider).go(route);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: route);
    }
  });
}
