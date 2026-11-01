import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartbin/data/api_smartbin_repository.dart';

Stream<List<int>> _bytes(List<String> chunks) => Stream.fromIterable(chunks.map(utf8.encode));

void main() {
  group('sseData', () {
    test('menggabungkan chunk yang terpotong di tengah baris menjadi satu event', () async {
      final events = await sseData(_bytes(['data: {"kind"', ':"status"}\n', '\n'])).toList();

      expect(events, ['{"kind":"status"}']);
    });

    test('mengabaikan komentar keepalive dan field selain data', () async {
      final events = await sseData(_bytes([': keepalive\n\n', 'event: x\nid: 7\ndata: kedua\n\n'])).toList();

      expect(events, ['kedua']);
    });

    test('menyambung beberapa baris data dalam satu event', () async {
      final events = await sseData(_bytes(['data: a\ndata: b\n\n', 'data: c\n\n'])).toList();

      expect(events, ['a\nb', 'c']);
    });

    test('event tanpa baris kosong penutup tidak dikirim', () async {
      final events = await sseData(_bytes(['data: belum selesai\n'])).toList();

      expect(events, isEmpty);
    });
  });

  group('isMachineStatusEvent', () {
    test('hanya menerima event berjenis status', () {
      expect(isMachineStatusEvent('{"deviceId":"esp1","kind":"status"}'), isTrue);
      expect(isMachineStatusEvent('{"deviceId":"esp1","kind":"deposit"}'), isFalse);
      expect(isMachineStatusEvent('{"deviceId":"esp1","kind":"auth"}'), isFalse);
    });

    test('mengabaikan payload yang bukan JSON objek', () {
      expect(isMachineStatusEvent('bukan json'), isFalse);
      expect(isMachineStatusEvent('[1,2]'), isFalse);
      expect(isMachineStatusEvent('"status"'), isFalse);
    });
  });
}
