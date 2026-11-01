import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbin/data/mock_smartbin_repository.dart';
import 'package:smartbin/data/models.dart';
import 'package:smartbin/state/providers.dart';

Deposit _deposit(int i) => Deposit(
  transactionId: 't$i',
  machineId: 'm',
  machineName: 'Unit',
  type: WasteType.organik,
  itemLabel: '',
  weightG: 100,
  points: 4,
  ratePerKg: 40,
  deviceTime: DateTime.utc(2026, 11, 1).subtract(Duration(minutes: i)),
  receivedAt: DateTime.utc(2026, 11, 1),
  status: DepositStatus.credited,
);

/// 45 setoran dengan paginasi cursor seperti server; [failCursorRequests] mensimulasikan jaringan putus saat memuat halaman berikutnya.
class _PagedRepository extends MockSmartbinRepository {
  _PagedRepository() : super(latency: Duration.zero);

  static const total = 45;
  bool failCursorRequests = false;
  int pageCalls = 0;

  @override
  Future<DepositPage> depositsPage({WasteType? type, DateTime? from, DateTime? to, String? cursor, int limit = 20}) async {
    pageCalls++;
    if (cursor != null && failCursorRequests) throw const AppException('Koneksi putus.');
    final start = int.tryParse(cursor ?? '') ?? 0;
    final end = start + limit < total ? start + limit : total;
    return DepositPage(items: [for (var i = start; i < end; i++) _deposit(i)], nextCursor: end < total ? '$end' : null);
  }
}

class _EventRepository extends MockSmartbinRepository {
  _EventRepository() : super(latency: Duration.zero);

  final events = StreamController<void>.broadcast();
  int machineCalls = 0;

  @override
  Future<List<Machine>> machines() {
    machineCalls++;
    return super.machines();
  }

  @override
  Stream<void> machineStatusEvents() => events.stream;
}

void main() {
  group('riwayat setoran berhalaman', () {
    const DepositFilter filter = (type: null, from: null, to: null);

    ProviderContainer containerFor(_PagedRepository repo) {
      final container = ProviderContainer(overrides: [repositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      container.listen(depositHistoryProvider(filter), (_, _) {}); // autoDispose: jaga tetap hidup selama test
      return container;
    }

    test('halaman pertama hanya memuat satu halaman, loadMore menambah sampai habis', () async {
      final repo = _PagedRepository();
      final container = containerFor(repo);

      final first = await container.read(depositHistoryProvider(filter).future);
      expect(first.items, hasLength(20));
      expect(first.hasMore, isTrue);
      expect(repo.pageCalls, 1);

      final notifier = container.read(depositHistoryProvider(filter).notifier);
      await notifier.loadMore();
      expect(container.read(depositHistoryProvider(filter)).value!.items, hasLength(40));

      await notifier.loadMore();
      final last = container.read(depositHistoryProvider(filter)).value!;
      expect(last.items, hasLength(45));
      expect(last.hasMore, isFalse);
      expect(last.items.map((d) => d.transactionId).toSet(), hasLength(45), reason: 'tidak boleh ada setoran ganda');

      await notifier.loadMore();
      expect(repo.pageCalls, 3, reason: 'tidak memanggil server lagi setelah halaman terakhir');
    });

    test('gagal memuat halaman berikutnya mempertahankan daftar dan bisa dicoba lagi', () async {
      final repo = _PagedRepository();
      final container = containerFor(repo);
      await container.read(depositHistoryProvider(filter).future);
      final notifier = container.read(depositHistoryProvider(filter).notifier);

      repo.failCursorRequests = true;
      await notifier.loadMore();
      final failed = container.read(depositHistoryProvider(filter)).value!;
      expect(failed.items, hasLength(20));
      expect(failed.loadMoreError, isA<AppException>());
      expect(failed.loadingMore, isFalse);
      expect(failed.hasMore, isTrue);

      repo.failCursorRequests = false;
      await notifier.loadMore();
      final recovered = container.read(depositHistoryProvider(filter)).value!;
      expect(recovered.items, hasLength(40));
      expect(recovered.loadMoreError, isNull);
    });

    test('loadMore yang dipanggil beruntun tidak memuat halaman yang sama dua kali', () async {
      final repo = _PagedRepository();
      final container = containerFor(repo);
      await container.read(depositHistoryProvider(filter).future);
      final notifier = container.read(depositHistoryProvider(filter).notifier);

      await Future.wait([notifier.loadMore(), notifier.loadMore(), notifier.loadMore()]);

      expect(container.read(depositHistoryProvider(filter)).value!.items, hasLength(40));
      expect(repo.pageCalls, 2);
    });
  });

  group('DepositStats', () {
    test('of(null) menjumlahkan semua jenis', () {
      const stats = DepositStats(
        organik: DepositTypeStats(count: 3, weightG: 1500, points: 60),
        anorganik: DepositTypeStats(count: 2, weightG: 800, points: 80),
        residu: DepositTypeStats(count: 1, weightG: 500, points: 0),
      );

      final total = stats.of(null);
      expect((total.count, total.weightG, total.points), (6, 2800, 140));
      expect(stats.of(WasteType.residu).count, 1);
    });
  });

  group('status mesin realtime', () {
    test('setiap event SSE memuat ulang daftar mesin, termasuk event berulang', () async {
      final repo = _EventRepository();
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo), machinesRefreshIntervalProvider.overrideWithValue(null)],
      );
      addTearDown(() {
        container.dispose();
        repo.events.close();
      });
      container.listen(machinesProvider, (_, _) {});
      await container.read(machinesProvider.future);
      expect(repo.machineCalls, 1);

      // Event pertama dan kedua bernilai sama (void); keduanya tetap harus memicu muat ulang.
      repo.events.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      expect(repo.machineCalls, 2);

      repo.events.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      expect(repo.machineCalls, 3);
    });

    test('rentetan event dalam satu detik digabung menjadi satu muat ulang', () async {
      final repo = _EventRepository();
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo), machinesRefreshIntervalProvider.overrideWithValue(null)],
      );
      addTearDown(() {
        container.dispose();
        repo.events.close();
      });
      container.listen(machinesProvider, (_, _) {});
      await container.read(machinesProvider.future);

      for (var i = 0; i < 5; i++) {
        repo.events.add(null);
      }
      await Future<void>.delayed(const Duration(milliseconds: 1600));

      expect(repo.machineCalls, 2);
    });
  });
}
