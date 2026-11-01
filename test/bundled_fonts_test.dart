import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Font dibundel di `google_fonts/`; tanpa pengunduhan runtime, semua bobot yang dipakai tema harus ada di aset.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const files = ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'];

  test('berkas font terdaftar di pubspec dan bisa dimuat dari asset bundle', () async {
    for (final name in files) {
      final data = await rootBundle.load('google_fonts/PlusJakartaSans-$name.ttf');
      expect(data.lengthInBytes, greaterThan(10000), reason: 'PlusJakartaSans-$name.ttf');
    }
  });

  test('google_fonts memuat semua bobot dari aset tanpa mencoba mengunduh', () async {
    GoogleFonts.config.allowRuntimeFetching = false;
    addTearDown(() => GoogleFonts.config.allowRuntimeFetching = true);

    // google_fonts menelan error pemuatan dan hanya mencetaknya, jadi log ditangkap dan diperiksa.
    final logs = <String>[];
    await runZoned(() async {
      // w900 dipakai di beberapa layar; google_fonts memetakannya ke varian terdekat (w800).
      for (final weight in [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800, FontWeight.w900]) {
        GoogleFonts.plusJakartaSans(fontWeight: weight);
      }
      await GoogleFonts.pendingFonts();
    }, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logs.add(line)));

    expect(
      logs.where((l) => l.contains('allowRuntimeFetching') || l.contains('Failed') || l.contains('not found')),
      isEmpty,
      reason: logs.join('\n'),
    );
  });
}
