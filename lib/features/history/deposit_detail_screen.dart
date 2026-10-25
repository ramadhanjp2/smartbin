import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// S07 – Detail setoran.
class DepositDetailScreen extends ConsumerWidget {
  const DepositDetailScreen({super.key, required this.transactionId});
  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(depositDetailProvider(transactionId));
    return Scaffold(
      appBar: const SmartbinAppBar(title: 'Detail Transaksi', showBack: true),
      body: switch (detail) {
        AsyncValue(:final value?) => _Body(deposit: value),
        AsyncValue(:final error?) => Padding(
          padding: const EdgeInsets.all(20),
          child: ErrorView(error: error, onRetry: () => ref.invalidate(depositDetailProvider(transactionId))),
        ),
        _ => const Padding(padding: EdgeInsets.all(20), child: SkeletonList(count: 4)),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.deposit});
  final Deposit deposit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = deposit;
    final user = ref.watch(currentUserProvider);
    final balance = ref.watch(pointsSummaryProvider).value?.balance;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Ringkasan utama
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: p.card,
            border: Border.all(color: p.border.withValues(alpha: 0.6)),
            gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [p.accentSoft.withValues(alpha: 0.35), p.card]),
          ),
          child: Column(
            children: [
              d.isHeld
                  ? const StatusPill(label: 'Menunggu Tautan KTM', tone: PillTone.warning, icon: Icons.schedule)
                  : const StatusPill(label: 'Terkreditasi ke Saldo KTM', icon: Icons.check_circle),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(Fmt.signedPoints(d.points), style: context.text.displayLarge?.copyWith(color: d.isHeld ? p.warning : p.textPrimary)),
                  const SizedBox(width: 8),
                  Text('Poin', style: context.text.headlineSmall?.copyWith(color: p.textMuted)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Setoran Sampah ${d.type.label} (${d.itemLabel})',
                textAlign: TextAlign.center,
                style: context.text.titleMedium?.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule, size: 16, color: p.textMuted),
                  const SizedBox(width: 6),
                  Text(Fmt.dateTime(d.deviceTime), style: context.text.bodySmall?.copyWith(color: p.textMuted)),
                ],
              ),
              if (d.isHeld && user != null && !user.isCardLinked) ...[
                const SizedBox(height: 16),
                Text(
                  'Poin ini akan masuk ke saldo setelah KTM Anda ditautkan.',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(color: p.warning),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: () => context.push('/link-ktm'), icon: const Icon(Icons.contactless), label: const Text('Tautkan KTM')),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Rumus poin
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(icon: Icons.calculate_outlined, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Kalkulasi Formula Poin', style: context.text.titleMedium?.copyWith(color: p.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Row(label: 'Kategori Material', value: '${d.itemLabel} · ${d.type.label}'),
              _Row(label: 'Bobot Terukur (Load Cell)', value: '${Fmt.kg(d.weightG)} kg'),
              _Row(label: 'Tarif Poin', value: '${d.ratePerKg} Poin / kg'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Perhitungan Mesin:', style: context.text.labelMedium?.copyWith(color: p.textMuted)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: Text('${Fmt.kg(d.weightG)} kg × ${d.ratePerKg} Poin/kg', style: context.text.labelLarge)),
                        Text(
                          '= ${Fmt.points(d.points)} Poin',
                          style: context.text.headlineSmall?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Waktu & sinkronisasi
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(icon: Icons.memory, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Validasi Perangkat IoT', style: context.text.titleMedium?.copyWith(color: p.textSecondary)),
                        Text('Telemetri mesin tercatat otomatis', style: context.text.bodySmall?.copyWith(color: p.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _InfoTile(
                icon: Icons.scale_outlined,
                title: 'Modul Sensor Berat',
                subtitle: 'Load Cell HX711',
                trailing: const StatusPill(label: 'Akurat (±5g)'),
              ),
              _InfoTile(
                icon: Icons.timer_outlined,
                title: 'Jam RTC Mesin',
                subtitle: 'DS3231 · waktu setoran',
                trailingText: Fmt.timeWithSeconds(d.deviceTime),
              ),
              _InfoTile(
                icon: Icons.cloud_sync_outlined,
                title: 'Diterima Server',
                subtitle: d.wasDelayed ? 'Mesin sempat offline' : 'Sinkron via MQTT',
                trailingText: d.wasDelayed ? Fmt.dateTime(d.receivedAt) : Fmt.timeWithSeconds(d.receivedAt),
                warn: d.wasDelayed,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Identitas
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(icon: Icons.fingerprint, size: 40),
                  const SizedBox(width: 12),
                  Text('Identitas & Keamanan', style: context.text.titleMedium?.copyWith(color: p.textSecondary)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID TRANSAKSI UNIK', style: context.text.labelSmall?.copyWith(color: p.textMuted)),
                          const SizedBox(height: 2),
                          SelectableText(
                            d.transactionId,
                            style: context.text.labelLarge?.copyWith(fontFamily: 'monospace', color: p.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: d.transactionId));
                        showSnack(context, 'ID transaksi disalin');
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Salin'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _Row(label: 'Mesin', value: d.machineName),
              _Row(label: 'Status KTM', value: user?.card != null ? 'Tertaut · ****${user!.card!.uidHashSuffix}' : 'Belum tertaut'),
              if (balance != null) _Row(label: 'Total Saldo Poin Akun', value: '${Fmt.points(balance)} Poin', strong: true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(24)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                child: Icon(Icons.eco_outlined, color: p.accentSoft),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DAMPAK KEBERLANJUTANMU', style: context.text.labelSmall?.copyWith(color: p.accentSoft, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text('${Fmt.kg(d.weightG)} kg sampah terpilah dengan benar', style: context.text.titleMedium?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      d.type == WasteType.organik
                          ? 'Sampah organik ini bisa diolah menjadi kompos untuk taman kampus. Terima kasih, pahlawan hijau!'
                          : 'Material anorganik ini siap didaur ulang, bukan berakhir di TPA. Terima kasih, pahlawan hijau!',
                      style: context.text.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.go('/machines'),
          icon: const Icon(Icons.sensors),
          label: const Text('Lihat Status Mesin SmartBIN'),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.strong = false});
  final String label, value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: context.text.bodyMedium?.copyWith(color: p.textMuted)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: (strong ? context.text.headlineSmall : context.text.labelLarge)?.copyWith(color: strong ? p.textPrimary : p.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.subtitle, this.trailing, this.trailingText, this.warn = false});
  final IconData icon;
  final String title, subtitle;
  final Widget? trailing;
  final String? trailingText;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: warn ? p.warningSoft : p.cardMuted, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: warn ? p.warning : p.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.labelLarge?.copyWith(color: p.textSecondary)),
                Text(subtitle, style: context.text.bodySmall?.copyWith(color: warn ? p.warning : p.textMuted)),
              ],
            ),
          ),
          ?trailing,
          if (trailingText != null) Text(trailingText!, style: context.text.labelMedium?.copyWith(color: warn ? p.warning : p.textSecondary)),
        ],
      ),
    );
  }
}
