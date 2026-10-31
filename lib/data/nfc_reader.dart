import 'dart:async';
import 'dart:math';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart' as nfc;
import 'package:nfc_manager/nfc_manager_android.dart' as nfc_android;

enum NfcAvailability { available, disabled, notSupported }

class NfcReaderException implements Exception {
  const NfcReaderException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class NfcReader {
  Future<NfcAvailability> availability();

  /// Reads only the card UID; card contents and personal data are not read.
  Future<String> readUid({Duration timeout = const Duration(seconds: 20)});

  Future<void> cancel();

  Future<void> openSettings();
}

class PlatformNfcReader implements NfcReader {
  Completer<String>? _activeScan;
  bool _sessionActive = false;

  @override
  Future<NfcAvailability> availability() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return NfcAvailability.notSupported;
    }

    return switch (await nfc.NfcManager.instance.checkAvailability()) {
      nfc.NfcAvailability.enabled => NfcAvailability.available,
      nfc.NfcAvailability.disabled => NfcAvailability.disabled,
      nfc.NfcAvailability.unsupported => NfcAvailability.notSupported,
    };
  }

  @override
  Future<String> readUid({Duration timeout = const Duration(seconds: 20)}) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw const NfcReaderException('Pemindaian KTP NFC hanya tersedia di Android.');
    }
    if (await availability() != NfcAvailability.available) {
      throw const NfcReaderException('NFC belum tersedia atau belum diaktifkan di ponsel.');
    }
    if (_activeScan != null) {
      throw const NfcReaderException('Pemindaian NFC sedang berlangsung.');
    }

    final scan = Completer<String>();
    _activeScan = scan;
    _sessionActive = true;
    Timer? timeoutTimer;

    try {
      await nfc.NfcManager.instance.startSession(
        pollingOptions: const {nfc.NfcPollingOption.iso14443},
        alertMessageIos: 'Tempelkan kartu e-KTP ke bagian belakang ponsel.',
        onDiscovered: (tag) {
          if (scan.isCompleted) return;
          final identifier = nfc_android.NfcTagAndroid.from(tag)?.id;
          if (identifier == null || identifier.isEmpty) {
            unawaited(_completeWithError(scan, const NfcReaderException('Kartu tidak menyediakan UID yang dapat dibaca.')));
            return;
          }
          unawaited(_completeWithUid(scan, identifier));
        },
      );
      timeoutTimer = Timer(timeout, () {
        unawaited(_completeWithError(scan, TimeoutException('Kartu tidak terdeteksi. Tempelkan kartu lebih lama di bagian belakang ponsel.')));
      });
      return await scan.future;
    } catch (error, stackTrace) {
      if (!scan.isCompleted) {
        await _stopSession();
        scan.completeError(error, stackTrace);
      }
      return await scan.future;
    } finally {
      timeoutTimer?.cancel();
      if (identical(_activeScan, scan)) _activeScan = null;
    }
  }

  Future<void> _completeWithUid(Completer<String> scan, List<int> identifier) async {
    try {
      await _stopSession();
      if (!scan.isCompleted) scan.complete(nfcUidToHex(identifier));
    } catch (error, stackTrace) {
      if (!scan.isCompleted) scan.completeError(error, stackTrace);
    }
  }

  Future<void> _completeWithError(Completer<String> scan, Object error) async {
    try {
      await _stopSession();
      if (!scan.isCompleted) scan.completeError(error);
    } catch (stopError, stackTrace) {
      if (!scan.isCompleted) scan.completeError(stopError, stackTrace);
    }
  }

  Future<void> _stopSession() async {
    if (!_sessionActive) return;
    _sessionActive = false;
    await nfc.NfcManager.instance.stopSession();
  }

  @override
  Future<void> cancel() async {
    final scan = _activeScan;
    if (scan == null || scan.isCompleted) return;
    await _completeWithError(scan, const NfcReaderException('Pemindaian NFC dibatalkan.'));
  }

  @override
  Future<void> openSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await const AndroidIntent(action: 'android.settings.NFC_SETTINGS').launch();
  }
}

String nfcUidToHex(List<int> identifier) {
  if ((identifier.length != 4 && identifier.length != 7 && identifier.length != 10) ||
      identifier.any((byte) => byte < 0 || byte > 0xff)) {
    throw const NfcReaderException('Format UID kartu NFC tidak didukung.');
  }
  return identifier.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
}

class MockNfcReader implements NfcReader {
  final _rng = Random();

  @override
  Future<NfcAvailability> availability() async => NfcAvailability.available;

  @override
  Future<String> readUid({Duration timeout = const Duration(seconds: 20)}) async {
    await Future.delayed(const Duration(milliseconds: 2200));
    return nfcUidToHex(List.generate(7, (_) => _rng.nextInt(256)));
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> openSettings() async {}
}
