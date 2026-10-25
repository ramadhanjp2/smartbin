import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

IconData depositIcon(Deposit d) {
  final l = d.itemLabel.toLowerCase();
  if (l.contains('makanan') || l.contains('kopi')) return Icons.restaurant;
  if (l.contains('daun') || l.contains('taman')) return Icons.park_outlined;
  if (l.contains('buah')) return Icons.eco_outlined;
  if (l.contains('kardus') || l.contains('kertas')) return Icons.inventory_2_outlined;
  if (l.contains('kaleng')) return Icons.local_cafe_outlined;
  if (l.contains('cup')) return Icons.coffee_outlined;
  return d.type == WasteType.organik ? Icons.compost : Icons.local_drink_outlined;
}

/// Kartu setoran: dipakai di Beranda (3 terakhir) dan Riwayat.
class DepositTile extends StatelessWidget {
  const DepositTile({super.key, required this.deposit, required this.now, this.detailed = false});

  final Deposit deposit;
  final DateTime now;

  /// Varian Riwayat: menampilkan sesi + chip kategori.
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = deposit;
    final held = d.isHeld;
    final pointColor = held ? p.warning : p.textPrimary;
    final statusPill = held
        ? const StatusPill(label: 'Menunggu Tautan KTM', tone: PillTone.warning, icon: Icons.schedule)
        : const StatusPill(label: 'Terkreditasi', icon: Icons.check_circle);

    return Semantics(
      button: true,
      label: '${d.itemLabel}, ${Fmt.kg(d.weightG)} kilogram, ${d.points} poin, ${held ? 'tertahan' : 'terkreditasi'}',
      child: SectionCard(
        padding: const EdgeInsets.all(16),
        onTap: () => context.push('/deposit/${d.transactionId}'),
        child: detailed ? _detailed(context, p, pointColor, statusPill) : _compact(context, p, pointColor, held),
      ),
    );
  }

  Widget _compact(BuildContext context, AppPalette p, Color pointColor, bool held) {
    final d = deposit;
    return Row(
      children: [
        IconTile(icon: depositIcon(d), size: 52, background: held ? p.warningSoft : p.cardMuted, foreground: held ? p.warning : p.textPrimary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d.itemLabel,
                style: context.text.titleMedium?.copyWith(color: p.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text('${Fmt.kg(d.weightG)} kg · ${Fmt.relativeShort(d.deviceTime, now)}', style: context.text.bodySmall?.copyWith(color: p.textMuted)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Fmt.signedPoints(d.points),
              style: context.text.headlineSmall?.copyWith(color: pointColor, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            held ? const StatusPill(label: 'Tertahan', tone: PillTone.warning, icon: Icons.schedule) : const StatusPill(label: 'Terkreditasi'),
          ],
        ),
      ],
    );
  }

  Widget _detailed(BuildContext context, AppPalette p, Color pointColor, Widget statusPill) {
    final d = deposit;
    final organic = d.type == WasteType.organik;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(icon: depositIcon(d), size: 44, background: organic ? p.accentSoft : p.cardMuted, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.itemLabel, style: context.text.titleMedium?.copyWith(color: p.textSecondary)),
                  Text('Sesi ${d.type.label} · ${Fmt.time(d.deviceTime)}', style: context.text.bodySmall?.copyWith(color: p.textMuted)),
                ],
              ),
            ),
            statusPill,
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: organic ? p.accentSoft : p.cardMuted, borderRadius: BorderRadius.circular(6)),
              child: Text(d.type.label, style: context.text.labelMedium?.copyWith(color: p.textPrimary)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Bobot: ${Fmt.kg(d.weightG)} kg', style: context.text.bodySmall?.copyWith(color: p.textMuted)),
            ),
            Text(
              Fmt.signedPoints(d.points),
              style: context.text.headlineSmall?.copyWith(color: pointColor, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 4),
            Text('Poin', style: context.text.labelMedium?.copyWith(color: pointColor)),
          ],
        ),
        if (d.wasDelayed) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 16, color: p.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mesin sempat offline; data dikirim saat mesin kembali online.',
                    style: context.text.bodySmall?.copyWith(color: p.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
