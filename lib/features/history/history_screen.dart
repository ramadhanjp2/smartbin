import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import 'deposit_tile.dart';

/// S06 – Riwayat setoran, dikelompokkan per hari.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  static const DepositRange _allTime = (from: null, to: null);

  WasteType? _type;
  DateTimeRange? _range;

  Future<void> _pickRange() async {
    final now = Fmt.dateOnlyWib(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: _range,
      locale: const Locale('id', 'ID'),
      helpText: 'Pilih rentang tanggal',
    );
    if (picked != null) setState(() => _range = picked);
  }

  /// Rentang tanggal kalender WIB diubah menjadi batas waktu absolut untuk server (hari terakhir inklusif).
  DepositRange get _rangeInstants {
    final r = _range;
    if (r == null) return _allTime;
    const wib = Duration(hours: 7);
    final from = DateTime.utc(r.start.year, r.start.month, r.start.day).subtract(wib);
    final to = DateTime.utc(r.end.year, r.end.month, r.end.day + 1).subtract(wib).subtract(const Duration(milliseconds: 1));
    return (from: from, to: to);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final range = _rangeInstants;
    final DepositFilter filter = (type: _type, from: range.from, to: range.to);
    final history = ref.watch(depositHistoryProvider(filter));
    // Hitungan di chip mencakup semua tanggal; kartu aktivitas mengikuti rentang tanggal yang dipilih.
    final statsAll = ref.watch(depositStatsProvider(_allTime));
    final statsRange = _range == null ? statsAll : ref.watch(depositStatsProvider(range));
    final now = DateTime.now();
    int count(WasteType? t) => statsAll.value?.of(t).count ?? 0;

    return Scaffold(
      appBar: const SmartbinAppBar(title: 'Riwayat'),
      body: RefreshIndicator(
        color: p.brand,
        onRefresh: () async {
          ref.invalidate(depositHistoryProvider);
          ref.invalidate(depositStatsProvider);
          try {
            await ref.read(depositHistoryProvider(filter).future);
          } catch (_) {}
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Riwayat Setoran', style: context.text.headlineLarge?.copyWith(color: p.textPrimary)),
                ),
                const StatusPill(label: 'Terverifikasi', icon: Icons.verified_outlined),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Total ${count(null)} transaksi tercatat melalui jaringan IoT SmartBIN',
              style: context.text.bodySmall?.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TypeChip(
                    label: 'Semua (${count(null)})',
                    icon: Icons.done_all,
                    selected: _type == null,
                    onTap: () => setState(() => _type = null),
                  ),
                  _TypeChip(
                    label: 'Organik (${count(WasteType.organik)})',
                    icon: Icons.eco_outlined,
                    selected: _type == WasteType.organik,
                    onTap: () => setState(() => _type = WasteType.organik),
                  ),
                  _TypeChip(
                    label: 'Anorganik (${count(WasteType.anorganik)})',
                    icon: Icons.recycling,
                    selected: _type == WasteType.anorganik,
                    onTap: () => setState(() => _type = WasteType.anorganik),
                  ),
                  _TypeChip(
                    label: 'Residu (${count(WasteType.residu)})',
                    icon: Icons.delete_outline,
                    selected: _type == WasteType.residu,
                    onTap: () => setState(() => _type = WasteType.residu),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: Icon(Icons.calendar_month, size: 16, color: p.textPrimary),
                  label: Text(_range == null ? 'Semua tanggal' : '${Fmt.calendarDate(_range!.start)} – ${Fmt.calendarDate(_range!.end)}'),
                  onPressed: _pickRange,
                  backgroundColor: p.cardMuted,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                ),
                if (_range != null)
                  ActionChip(
                    avatar: Icon(Icons.close, size: 16, color: p.warning),
                    label: const Text('Hapus filter tanggal'),
                    onPressed: () => setState(() => _range = null),
                    backgroundColor: p.warningSoft,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            switch (history) {
              AsyncValue(:final value?) => _content(context, value, statsRange.value?.of(_type), filter, now),
              AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(depositHistoryProvider(filter))),
              _ => const SkeletonList(count: 5),
            },
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, DepositHistoryState state, DepositTypeStats? stats, DepositFilter filter, DateTime now) {
    final p = context.palette;
    final list = state.items;
    if (list.isEmpty) {
      return const EmptyView(
        icon: Icons.receipt_long_outlined,
        title: 'Belum ada setoran',
        message: 'Tidak ada setoran untuk filter ini. Coba ubah jenis sampah atau rentang tanggal.',
      );
    }

    // Angka kartu berasal dari server untuk seluruh riwayat pada filter ini, bukan dari halaman yang sudah dimuat.
    final total = stats?.count ?? list.length;
    final groups = <String, List<Deposit>>{};
    for (final d in list) {
      groups.putIfAbsent(Fmt.dayHeader(d.deviceTime, now), () => []).add(d);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.query_stats, color: p.textPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Aktivitas Setoran', style: context.text.titleMedium?.copyWith(color: p.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'Poin Terkumpul',
                      value: stats == null ? '…' : Fmt.signedPoints(stats.points),
                      unit: 'Poin',
                      foot: 'Poin aktif',
                      icon: Icons.stars_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Stat(
                      label: 'Total Bobot',
                      value: stats == null ? '…' : Fmt.kg(stats.weightG),
                      unit: 'kg',
                      foot: '$total kali pemilahan',
                      icon: Icons.hourglass_bottom,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (final e in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(e.key, style: context.text.titleMedium?.copyWith(color: p.textPrimary)),
                ),
                Text('${e.value.length} Setoran', style: context.text.labelMedium?.copyWith(color: p.textMuted)),
              ],
            ),
          ),
          for (final d in e.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DepositTile(deposit: d, now: now, detailed: true),
            ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(999)),
          child: Row(
            children: [
              Icon(Icons.offline_pin_outlined, size: 16, color: p.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Menampilkan ${list.length} dari $total transaksi', style: context.text.labelMedium?.copyWith(color: p.textMuted)),
              ),
            ],
          ),
        ),
        if (state.loadMoreError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              errorText(state.loadMoreError!),
              textAlign: TextAlign.center,
              style: context.text.labelMedium?.copyWith(color: p.error),
            ),
          ),
        if (state.hasMore)
          TextButton.icon(
            onPressed: state.loadingMore ? null : () => ref.read(depositHistoryProvider(filter).notifier).loadMore(),
            icon: state.loadingMore
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.expand_more),
            label: Text(state.loadMoreError != null ? 'Coba Lagi' : 'Muat Lebih Banyak Riwayat'),
          ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        avatar: Icon(icon, size: 18, color: selected ? Colors.white : p.textPrimary),
        label: Text(label),
        labelStyle: context.text.labelLarge?.copyWith(color: selected ? Colors.white : p.textPrimary, fontWeight: FontWeight.w700),
        selectedColor: p.brand,
        backgroundColor: p.card,
        side: BorderSide(color: selected ? p.brand : p.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.unit, required this.foot, required this.icon});
  final String label, value, unit, foot;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.labelMedium?.copyWith(color: p.textMuted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: context.text.headlineMedium?.copyWith(color: p.textPrimary)),
                const SizedBox(width: 6),
                Text(unit, style: context.text.labelMedium?.copyWith(color: p.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 14, color: p.success),
              const SizedBox(width: 4),
              Flexible(
                child: Text(foot, style: context.text.labelSmall?.copyWith(color: p.success)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
