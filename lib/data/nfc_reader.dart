import 'dart:math';

enum NfcAvailability { available, disabled, notSupported }

/// Pembaca UID KTM lewat NFC. Implementasi nyata (mis. `flutter_nfc_kit`)
/// cukup mengganti [MockNfcReader] di `nfcReaderProvider`.
abstract class NfcReader {
  Future<NfcAvailability> availability();

  /// Menunggu kartu ditempel dan mengembalikan UID (hex). UID hanya diteruskan
  /// ke `/cards/link`, tidak disimpan maupun dicatat di log.
  Future<String> readUid({Duration timeout = const Duration(seconds: 20)});

  Future<void> openSettings();
}

class MockNfcReader implements NfcReader {
  final _rng = Random();

  @override
  Future<NfcAvailability> availability() async => NfcAvailability.available;

  @override
  Future<String> readUid({Duration timeout = const Duration(seconds: 20)}) async {
    await Future.delayed(const Duration(milliseconds: 2200));
    return List.generate(7, (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  @override
  Future<void> openSettings() async {}
}
