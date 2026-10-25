import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../state/providers.dart';

/// S12 – Nilai poin dan panduan memilah sampah (konten panduan statis, tersedia offline).
class RatesGuideScreen extends ConsumerWidget {
  const RatesGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final rates = ref.watch(ratesProvider);

    return Scaffold(
      appBar: const SmartbinAppBar(title: 'Nilai Poin & Panduan', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text('Nilai Poin Saat Ini', style: context.text.headlineLarge?.copyWith(color: p.textPrimary)),
          const SizedBox(height: 4),
          Text('Poin dihitung oleh mesin dari berat sampah × nilai poin per kg.', style: context.text.bodyMedium?.copyWith(color: p.textMuted)),
          const SizedBox(height: 16),
          switch (rates) {
            AsyncValue(:final value?) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _BigRate(label: 'Anorganik', icon: Icons.recycling, value: value.anorganikPerKg),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BigRate(label: 'Organik', icon: Icons.compost, value: value.organikPerKg),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Diperbarui ${Fmt.dateTime(value.updatedAt)}', style: context.text.bodySmall?.copyWith(color: p.textMuted)),
              ],
            ),
            AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(ratesProvider)),
            _ => const Row(
              children: [
                Expanded(child: SkeletonCard(height: 120)),
                SizedBox(width: 12),
                Expanded(child: SkeletonCard(height: 120)),
              ],
            ),
          },
          const SizedBox(height: 28),
          const SectionHeader(title: 'Panduan Memilah Sampah', icon: Icons.menu_book_outlined),
          const _GuideCard(
            title: 'Organik',
            icon: Icons.compost,
            tone: PillTone.success,
            caption: 'Masukkan ke lubang ORGANIK',
            examples: ['Sisa makanan & nasi', 'Kulit buah & sayur', 'Daun & ranting kecil', 'Ampas kopi & teh', 'Tisu / kertas basah'],
          ),
          const SizedBox(height: 12),
          const _GuideCard(
            title: 'Anorganik',
            icon: Icons.recycling,
            tone: PillTone.brand,
            caption: 'Masukkan ke lubang ANORGANIK',
            examples: ['Botol plastik PET (kosongkan)', 'Kaleng minuman', 'Cup plastik', 'Kardus & kertas kering', 'Kemasan plastik bersih'],
          ),
          const SizedBox(height: 12),
          const _GuideCard(
            title: 'Residu (tidak diberi poin)',
            icon: Icons.block,
            tone: PillTone.error,
            caption: 'Ditolak mesin & tidak tampil di riwayat',
            examples: ['Popok & pembalut', 'Puntung rokok', 'Styrofoam kotor', 'Baterai & elektronik', 'Masker bekas'],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: p.warningSoft, borderRadius: BorderRadius.circular(18)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: p.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Jangan meminjamkan KTM untuk menyetor sampah. Setiap setoran tercatat ke akun pemilik KTM.',
                    style: context.text.bodySmall?.copyWith(color: p.textSecondary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BigRate extends StatelessWidget {
  const _BigRate({required this.label, required this.icon, required this.value});
  final String label;
  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, size: 40, background: p.accentSoft),
          const SizedBox(height: 12),
          Text(label, style: context.text.labelLarge?.copyWith(color: p.textMuted)),
          Text('$value', style: context.text.displayLarge?.copyWith(color: p.textPrimary)),
          Text('poin per kg', style: context.text.bodySmall?.copyWith(color: p.textMuted)),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.title, required this.icon, required this.tone, required this.caption, required this.examples});
  final String title, caption;
  final IconData icon;
  final PillTone tone;
  final List<String> examples;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: tone == PillTone.error ? p.error : p.textPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: context.text.titleMedium?.copyWith(color: p.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(caption, style: context.text.bodySmall?.copyWith(color: p.textMuted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final e in examples) StatusPill(label: e, tone: tone == PillTone.brand ? PillTone.neutral : tone)],
          ),
        ],
      ),
    );
  }
}
