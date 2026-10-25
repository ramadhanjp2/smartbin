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
  static const _pageSize = 20;

  WasteType? _type;
  DateTimeRange? _range;
  int _visible = _pageSize;

  Future<void> _pickRange() async {
    final now = DateTime.now();
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

  List<Deposit> _applyRange(List<Deposit> list) {
    final r = _range;
    if (r == null) return list;
    final end = r.end.add(const Duration(days: 1));
    return list.where((d) {
      final t = Fmt.toWib(d.deviceTime);
      final local = DateTime(t.year, t.month, t.day);
      return !local.isBefore(r.start) && local.isBefore(end);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final all = ref.watch(depositsProvider(null));
    final filtered = ref.watch(depositsProvider(_type));
    final now = DateTime.now();
    final allList = all.value ?? const <Deposit>[];
    int count(WasteType? t) => t == null ? allList.length : allList.where((d) => d.type == t).length;

    return Scaffold(
      appBar: const SmartbinAppBar(title: 'Riwayat'),
      body: RefreshIndicator(
        color: p.brand,
        onRefresh: () async {
          ref.invalidate(depositsProvider);
          try {
            await ref.read(depositsProvider(_type).future);
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
              'Total ${allList.length} transaksi tercatat melalui jaringan IoT SmartBIN',
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
            switch (filtered) {
              AsyncValue(:final value?) => _content(context, _applyRange(value), now),
              AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(depositsProvider(_type))),
              _ => const SkeletonList(count: 5),
            },
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<Deposit> list, DateTime now) {
    final p = context.palette;
    if (list.isEmpty) {
      return const EmptyView(
        icon: Icons.receipt_long_outlined,
        title: 'Belum ada setoran',
        message: 'Tidak ada setoran untuk filter ini. Coba ubah jenis sampah atau rentang tanggal.',
      );
    }

    final credited = list.where((d) => !d.isHeld);
    final points = credited.fold<int>(0, (s, d) => s + d.points);
    final grams = list.fold<int>(0, (s, d) => s + d.weightG);
    final shown = list.take(_visible).toList();

    final groups = <String, List<Deposit>>{};
    for (final d in shown) {
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
                      value: Fmt.signedPoints(points),
                      unit: 'Poin',
                      foot: 'Poin aktif',
                      icon: Icons.stars_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Stat(
                      label: 'Total Bobot',
                      value: Fmt.kg(grams),
                      unit: 'kg',
                      foot: '${list.length} kali pemilahan',
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
                child: Text(
                  'Menampilkan ${shown.length} dari ${list.length} transaksi',
                  style: context.text.labelMedium?.copyWith(color: p.textMuted),
                ),
              ),
            ],
          ),
        ),
        if (shown.length < list.length)
          TextButton.icon(
            onPressed: () => setState(() => _visible += _pageSize),
            icon: const Icon(Icons.expand_more),
            label: const Text('Muat Lebih Banyak Riwayat'),
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
