import 'package:flutter_test/flutter_test.dart';
import 'package:smartbin/data/nfc_reader.dart';

void main() {
  group('nfcUidToHex', () {
    test('normalizes NFC-A identifiers to the machine-compatible UID format', () {
      expect(nfcUidToHex([0x04, 0x0a, 0xbc, 0xff]), '040ABCFF');
      expect(nfcUidToHex([0x04, 0x0a, 0xbc, 0xff, 0x01, 0x02, 0x03]), '040ABCFF010203');
      expect(nfcUidToHex([0x04, 0x0a, 0xbc, 0xff, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06]), '040ABCFF010203040506');
    });

    test('rejects unsupported UID lengths', () {
      expect(() => nfcUidToHex([0x01, 0x02, 0x03]), throwsA(isA<NfcReaderException>()));
      expect(() => nfcUidToHex([0x01, 0x02, 0x03, 0x100]), throwsA(isA<NfcReaderException>()));
    });
  });
}
