import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../history/deposit_tile.dart';

/// S05 – Beranda.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(pointsSummaryProvider);
    ref.invalidate(depositsProvider(null));
    ref.invalidate(ratesProvider);
    ref.invalidate(notificationsProvider);
    try {
      await ref.read(pointsSummaryProvider.future);
    } catch (_) {
      // Galat ditampilkan oleh layar; data lama tetap terlihat.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final user = ref.watch(currentUserProvider);
    final summary = ref.watch(pointsSummaryProvider);
    final deposits = ref.watch(depositsProvider(null));
    final now = DateTime.now();

    return Scaffold(
      appBar: const SmartbinAppBar(title: 'Beranda'),
      body: RefreshIndicator(
        color: p.brand,
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (summary.isLoading && !summary.hasValue) const _SyncChip() else if (summary.hasError && summary.hasValue) const _StaleBanner(),
            _Greeting(user: user),
            const SizedBox(height: 16),
            if (user != null && !user.isCardLinked) ...[_LinkKtmBanner(heldPoints: summary.value?.heldPoints ?? 0), const SizedBox(height: 16)],
            switch (summary) {
              AsyncValue(:final value?) => _BalanceCard(summary: value),
              AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(pointsSummaryProvider)),
              _ => const _BalanceSkeleton(),
            },
            const SizedBox(height: 28),
            SectionHeader(
              title: 'Ringkasan Bulan Ini',
              icon: Icons.bar_chart,
              trailing: summary.value == null
                  ? null
                  : StatusPill(label: '${summary.value!.depositCount} kali setor', tone: PillTone.neutral, icon: Icons.done_all),
            ),
            switch (summary) {
              AsyncValue(:final value?) => _MonthSummary(summary: value),
              AsyncValue(hasError: true) => const SizedBox.shrink(),
              _ => const Row(
                children: [
                  Expanded(child: SkeletonCard(height: 140)),
                  SizedBox(width: 12),
                  Expanded(child: SkeletonCard(height: 140)),
                ],
              ),
            },
            const SizedBox(height: 16),
            SectionCard(
              padding: const EdgeInsets.all(16),
              onTap: () => context.go('/machines'),
              child: Row(
                children: [
                  IconTile(icon: Icons.qr_code_2, size: 52, background: p.brandDark, foreground: Colors.white),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sedang di Depan SmartBIN?', style: context.text.titleMedium?.copyWith(color: p.textSecondary)),
                        Text('Cek status mesin & kapasitas tong sebelum menyetor', style: context.text.bodySmall?.copyWith(color: p.textMuted)),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: p.cardMuted,
                    child: Icon(Icons.arrow_forward, color: p.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SectionHeader(
              title: 'Setoran Terakhir',
              icon: Icons.history,
              trailing: TextButton(onPressed: () => context.go('/history'), child: const Text('Lihat Semua')),
            ),
            switch (deposits) {
              AsyncValue(:final value?) when value.isEmpty => const EmptyView(
                icon: Icons.delete_outline,
                title: 'Belum ada setoran',
                message: 'Setor sampah di mesin SmartBIN terdekat untuk mulai mengumpulkan poin.',
              ),
              AsyncValue(:final value?) => Column(
                children: [
                  for (final d in value.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DepositTile(deposit: d, now: now),
                    ),
                ],
              ),
              AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(depositsProvider(null))),
              _ => const SkeletonList(count: 3),
            },
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(20)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: p.accentSoft,
                    child: Icon(Icons.lightbulb_outline, color: p.textPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Tips Eco: ',
                            style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary),
                          ),
                          const TextSpan(text: 'Pastikan botol plastik kosong dan terlipat untuk memaksimalkan kapasitas sensor berat SmartBIN!'),
                        ],
                      ),
                      style: context.text.bodySmall?.copyWith(color: p.textSecondary, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (summary.value != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sync, size: 14, color: p.textMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Diperbarui pukul ${Fmt.time(summary.value!.updatedAt)} · Tarik untuk segarkan',
                      style: context.text.bodySmall?.copyWith(color: p.textMuted),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SyncChip extends StatelessWidget {
  const _SyncChip();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.success)),
            const SizedBox(width: 8),
            Text('Menyinkronkan data SmartBIN…', style: context.text.labelMedium?.copyWith(color: p.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: p.warningSoft, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: p.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Mode offline · menampilkan data lama', style: context.text.labelMedium?.copyWith(color: p.warning)),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.user});
  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Halo, ${user?.firstName ?? 'Pengguna'}! 👋', style: context.text.headlineLarge?.copyWith(color: p.textPrimary)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.school_outlined, size: 16, color: p.textMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(user?.faculty ?? '', style: context.text.bodyMedium?.copyWith(color: p.textMuted)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: p.accentSoft, shape: BoxShape.circle),
          child: Icon(Icons.eco_outlined, color: p.textPrimary),
        ),
      ],
    );
  }
}

class _LinkKtmBanner extends StatelessWidget {
  const _LinkKtmBanner({required this.heldPoints});
  final int heldPoints;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SectionCard(
      color: p.cardMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: Icons.contactless_outlined, background: p.warningSoft, foreground: p.warning),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('KTP Belum Tertaut!', style: context.text.titleMedium?.copyWith(color: p.textSecondary)),
                        const StatusPill(label: 'Penting', tone: PillTone.warning),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Tautkan kartu KTP Anda '),
                          if (heldPoints > 0) ...[
                            const TextSpan(text: 'untuk mencairkan '),
                            TextSpan(
                              text: '${Fmt.points(heldPoints)} poin tertahan',
                              style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary),
                            ),
                            const TextSpan(text: ' ke saldo utama akun.'),
                          ] else
                            const TextSpan(text: 'agar setiap setoran langsung masuk ke saldo.'),
                        ],
                      ),
                      style: context.text.bodySmall?.copyWith(color: p.textSecondary, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20)),
              onPressed: () => context.push('/link-ktp'),
              icon: const Icon(Icons.add_card, size: 20),
              label: const Text('Tautkan Sekarang'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.summary});
  final PointsSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final rates = ref.watch(ratesProvider).value;
    const onBrand = Colors.white;
    final onBrandSoft = Colors.white.withValues(alpha: 0.75);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
        boxShadow: [BoxShadow(color: const Color(0xFF1B5E20).withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Stack(
        children: [
          Positioned(right: -40, bottom: -30, child: Icon(Icons.eco, size: 200, color: Colors.white.withValues(alpha: 0.06))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text('SALDO POIN ANDA', style: context.text.labelMedium?.copyWith(color: onBrandSoft, letterSpacing: 1.2)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events_outlined, size: 14, color: p.accentSoft),
                          const SizedBox(width: 4),
                          Text('Level ${summary.level} SmartBIN', style: context.text.labelSmall?.copyWith(color: p.accentSoft)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Semantics(
                  label: 'Saldo ${summary.balance} poin',
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(Fmt.points(summary.balance), style: context.text.displayLarge?.copyWith(color: onBrand)),
                      const SizedBox(width: 10),
                      Text('Poin', style: context.text.headlineSmall?.copyWith(color: p.accentSoft)),
                    ],
                  ),
                ),
                if (summary.heldPoints > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_bottom, size: 18, color: p.accentSoft),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${Fmt.points(summary.heldPoints)} poin tertahan',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(text: ' dari ${summary.heldDeposits} setoran menunggu KTP ditautkan'),
                              ],
                            ),
                            style: context.text.bodySmall?.copyWith(color: onBrand),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      IconTile(icon: Icons.calculate_outlined, size: 40, background: Colors.white.withValues(alpha: 0.14), foreground: p.accentSoft),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nilai Konversi Poin', style: context.text.labelLarge?.copyWith(color: onBrand)),
                            Text(
                              rates == null ? 'Memuat…' : 'Anorganik ${rates.anorganikPerKg} poin/kg · Organik ${rates.organikPerKg} poin/kg',
                              style: context.text.bodySmall?.copyWith(color: onBrandSoft),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: p.accentSoft,
                          foregroundColor: const Color(0xFF1B5E20),
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: context.text.labelMedium,
                        ),
                        onPressed: () => context.push('/rates'),
                        icon: const Icon(Icons.help_outline, size: 16),
                        label: const Text('Panduan'),
                      ),
                    ],
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

class _BalanceSkeleton extends StatelessWidget {
  const _BalanceSkeleton();

  @override
  Widget build(BuildContext context) => const SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(width: 120),
        SizedBox(height: 14),
        Skeleton(width: 180, height: 44, radius: 12),
        SizedBox(height: 14),
        Skeleton(height: 56, radius: 16),
        SizedBox(height: 14),
        Skeleton(height: 64, radius: 16),
      ],
    ),
  );
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.summary});
  final PointsSummary summary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget card(String title, IconData icon, int grams, int count, int points, bool accent) => Expanded(
      child: SectionCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTile(icon: icon, size: 40, background: accent ? p.accentSoft : p.cardMuted),
                const Spacer(),
                StatusPill(label: '$count setoran', tone: accent ? PillTone.success : PillTone.neutral),
              ],
            ),
            const SizedBox(height: 14),
            Text(title, style: context.text.bodySmall?.copyWith(color: p.textMuted)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(Fmt.kg(grams), style: context.text.headlineMedium?.copyWith(color: p.textSecondary)),
                const SizedBox(width: 4),
                Text('kg', style: context.text.bodySmall?.copyWith(color: p.textMuted)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.trending_up, size: 14, color: p.success),
                const SizedBox(width: 4),
                Text('${Fmt.signedPoints(points)} poin', style: context.text.labelMedium?.copyWith(color: p.success)),
              ],
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        card('Limbah Organik', Icons.compost, summary.organicG, summary.organicCount, summary.organicPoints, false),
        const SizedBox(width: 12),
        card('Limbah Anorganik', Icons.recycling, summary.inorganicG, summary.inorganicCount, summary.inorganicPoints, true),
      ],
    );
  }
}
