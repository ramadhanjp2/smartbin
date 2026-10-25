import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:smartbin/core/format/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('poin memakai pemisah ribuan titik', () {
    expect(Fmt.points(1450), '1.450');
    expect(Fmt.signedPoints(120), '+120');
  });

  test('berat gram dikonversi ke kg dengan koma desimal', () {
    expect(Fmt.kg(1200), '1,20');
    expect(Fmt.kg(950), '0,95');
  });

  test('waktu ditampilkan dalam WIB (UTC+7)', () {
    expect(Fmt.time(DateTime.utc(2026, 10, 24, 3, 15)), '10:15 WIB');
  });
}
