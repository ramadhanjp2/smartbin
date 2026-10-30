import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../machines/machines_screen.dart';

/// S16 – Dashboard admin: status semua mesin, nilai poin, reset status.
/// Peran admin juga diperiksa di server pada setiap endpoint `/admin/*`.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  String? _selectedId;

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari mode admin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (ok == true) await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final machines = ref.watch(machinesProvider);

    return Scaffold(
      appBar: EyebrowAppBar(
        eyebrow: 'SmartBIN',
        title: 'Dashboard Mesin',
        onBack: context.canPop() ? () => context.pop() : null,
        trailing: IconButton.filled(
          tooltip: 'Keluar',
          style: IconButton.styleFrom(backgroundColor: p.brandDark),
          onPressed: _logout,
          icon: const Icon(Icons.logout, color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        color: p.brand,
        onRefresh: () async {
          ref.invalidate(machinesProvider);
          ref.invalidate(ratesProvider);
          ref.invalidate(telemetryProvider);
          try {
            await ref.read(machinesProvider.future);
          } catch (_) {}
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(18)),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: p.brandDark,
                    child: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MODE AKSES TERBATAS',
                          style: context.text.labelMedium?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w800),
                        ),
                        Text('Khusus Admin & Pengelola Mesin SmartBIN', style: context.text.bodySmall?.copyWith(color: p.textSecondary)),
                      ],
                    ),
                  ),
                  const StatusPill(label: 'Teknisi', tone: PillTone.brand),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              onTap: () => context.go('/admin/users'),
              padding: const EdgeInsets.all(14),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: IconTile(icon: Icons.admin_panel_settings_outlined, size: 48),
                title: Text('Manajemen Admin'),
                subtitle: Text('Pengguna, mesin, history all, pencarian, export CSV & visualisasi'),
                trailing: Icon(Icons.arrow_forward_ios, size: 18),
              ),
            ),
            const SizedBox(height: 16),
            switch (machines) {
              AsyncValue(:final value?) when value.isNotEmpty => () {
                final selected = value.firstWhere((m) => m.id == _selectedId, orElse: () => value.first);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final m in value)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                selected: m.id == selected.id,
                                showCheckmark: false,
                                onSelected: (_) => setState(() => _selectedId = m.id),
                                avatar: Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: switch (m.status) {
                                    MachineStatus.siap => p.success,
                                    MachineStatus.penuh => p.warning,
                                    MachineStatus.gangguan => p.error,
                                    MachineStatus.offline => p.textMuted,
                                  },
                                ),
                                label: Text('${m.name.replaceFirst('SmartBIN ', '')} · ${m.status.label}'),
                                selectedColor: p.accentSoft,
                                backgroundColor: p.card,
                                side: BorderSide(color: p.border),
                                shape: const StadiumBorder(),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _UnitCard(machine: selected),
                    const SizedBox(height: 16),
                    _CapacityRow(machine: selected),
                    const SizedBox(height: 16),
                    _Diagnostics(machine: selected),
                    const SizedBox(height: 16),
                    const _RatesConfig(),
                    const SizedBox(height: 16),
                    _Controls(machine: selected),
                    const SizedBox(height: 16),
                    _TelemetryLog(machineId: selected.id),
                  ],
                );
              }(),
              AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(machinesProvider)),
              AsyncValue(hasValue: true) => const EmptyView(
                icon: Icons.sensors_off,
                title: 'Belum ada mesin',
                message: 'Belum ada mesin yang terdaftar.',
              ),
              _ => const SkeletonList(count: 4),
            },
          ],
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.machine});
  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = machine;
    final online = m.status != MachineStatus.offline;
    Widget stat(String label, IconData icon, String value) => Expanded(
      child: Column(
        children: [
          Text(label, style: context.text.labelMedium?.copyWith(color: p.textMuted)),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: online ? p.textPrimary : p.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  style: context.text.labelLarge?.copyWith(color: online ? p.textPrimary : p.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              IconTile(icon: Icons.inventory_2_outlined, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name.replaceFirst('SmartBIN ', ''), style: context.text.headlineLarge?.copyWith(color: p.textSecondary)),
                    const SizedBox(height: 2),
                    StatusPill(label: machineStatusText(m.status), tone: machineTone(m.status), dot: true),
                    const SizedBox(height: 4),
                    Text(m.location, style: context.text.bodySmall?.copyWith(color: p.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                stat('Heartbeat', Icons.favorite_border, Fmt.ago(m.lastSeen, DateTime.now()).replaceAll(' lalu', '')),
                stat('MQTT Broker', Icons.cloud_done_outlined, online ? 'Terhubung' : 'Terputus'),
                stat('RTC DS3231', Icons.sync, online ? 'Sync' : '–'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapacityRow extends StatelessWidget {
  const _CapacityRow({required this.machine});
  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget bin(String label, int percent, int cm) {
      final color = FillBar.fillColor(context, percent);
      return Expanded(
        child: SectionCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusPill(label: label, tone: label == 'Organik' ? PillTone.neutral : PillTone.success),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$percent%',
                    style: context.text.headlineLarge?.copyWith(color: color, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    percent >= 90
                        ? 'Penuh'
                        : percent >= 75
                        ? 'Waspada'
                        : 'Aman',
                    style: context.text.labelMedium?.copyWith(color: color),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FillBar(percent: percent),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Text('Sisa Jarak Sensor', style: context.text.labelSmall?.copyWith(color: p.textMuted)),
                    Text('$cm cm lagi', style: context.text.labelLarge?.copyWith(color: p.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Kapasitas Kompartemen', style: context.text.headlineSmall?.copyWith(color: p.textSecondary)),
            ),
            Text('Ultrasonik HC-SR04', style: context.text.labelMedium?.copyWith(color: p.textMuted)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            bin('Organik', machine.organicFill, machine.organicCmLeft),
            const SizedBox(width: 12),
            bin('Anorganik', machine.inorganicFill, machine.inorganicCmLeft),
          ],
        ),
      ],
    );
  }
}

class _Diagnostics extends StatelessWidget {
  const _Diagnostics({required this.machine});
  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final allOk = machine.modules.every((m) => m.ok);
    return SectionCard(
      child: Column(
        children: [
          SectionHeader(
            title: 'Diagnostik Sensor & Modul',
            icon: Icons.memory,
            trailing: StatusPill(label: allOk ? 'Semua Normal' : 'Perlu Dicek', tone: allOk ? PillTone.success : PillTone.error, dot: true),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              for (final mod in machine.modules)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: mod.ok ? p.cardMuted : p.errorSoft, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Icon(mod.ok ? Icons.check_circle_outline : Icons.error_outline, color: mod.ok ? p.success : p.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mod.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelMedium?.copyWith(color: p.textSecondary),
                            ),
                            Text(
                              mod.detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall?.copyWith(color: p.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatesConfig extends ConsumerStatefulWidget {
  const _RatesConfig();

  @override
  ConsumerState<_RatesConfig> createState() => _RatesConfigState();
}

class _RatesConfigState extends ConsumerState<_RatesConfig> {
  int? _anorganik;
  int? _organik;
  bool _busy = false;

  Future<void> _publish(Rates current) async {
    final a = _anorganik ?? current.anorganikPerKg;
    final o = _organik ?? current.organikPerKg;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publikasikan nilai poin?'),
        content: Text(
          'Anorganik: ${current.anorganikPerKg} → $a poin/kg\nOrganik: ${current.organikPerKg} → $o poin/kg\n\n'
          'Nilai dikirim sebagai pesan config (retained) ke semua mesin. Perubahan dicatat atas nama Anda.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Publikasikan')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).updateRates(organikPerKg: o, anorganikPerKg: a);
      ref.invalidate(ratesProvider);
      setState(() {
        _anorganik = null;
        _organik = null;
      });
      if (mounted) showSnack(context, 'Konfigurasi nilai poin dipublikasikan');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rates = ref.watch(ratesProvider);
    return SectionCard(
      child: switch (rates) {
        AsyncValue(:final value?) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Konfigurasi Nilai Poin',
              icon: Icons.tune,
              trailing: Text('MQTT Retained', style: context.text.labelMedium?.copyWith(color: p.textMuted)),
            ),
            Text('Nilai poin disinkronkan otomatis ke seluruh mesin SmartBIN.', style: context.text.bodySmall?.copyWith(color: p.textMuted)),
            const SizedBox(height: 12),
            _Stepper(
              badge: 'ANO',
              title: 'Anorganik',
              subtitle: 'Poin per kg',
              value: _anorganik ?? value.anorganikPerKg,
              onChanged: (v) => setState(() => _anorganik = v),
            ),
            const SizedBox(height: 8),
            _Stepper(
              badge: 'BIO',
              title: 'Organik',
              subtitle: 'Poin per kg',
              value: _organik ?? value.organikPerKg,
              onChanged: (v) => setState(() => _organik = v),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: p.brandDark),
              onPressed: _busy || (_anorganik == null && _organik == null) ? null : () => _publish(value),
              icon: const Icon(Icons.publish),
              label: const Text('Publikasi Konfigurasi'),
            ),
          ],
        ),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(ratesProvider)),
        _ => const Skeleton(height: 180, radius: 16),
      },
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.badge, required this.title, required this.subtitle, required this.value, required this.onChanged});
  final String badge, title, subtitle;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.brand, borderRadius: BorderRadius.circular(10)),
            child: Text(badge, style: context.text.labelMedium?.copyWith(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.labelLarge?.copyWith(color: p.textSecondary)),
                Text(subtitle, style: context.text.bodySmall?.copyWith(color: p.textMuted)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(999)),
            child: Row(
              children: [
                IconButton(tooltip: 'Kurangi', onPressed: value > 5 ? () => onChanged(value - 5) : null, icon: const Icon(Icons.remove)),
                SizedBox(
                  width: 40,
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: context.text.headlineSmall?.copyWith(color: p.textPrimary),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Tambah',
                  style: IconButton.styleFrom(backgroundColor: p.accentSoft, foregroundColor: p.textPrimary),
                  onPressed: value < 1000 ? () => onChanged(value + 5) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.machine});
  final Machine machine;

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.restart_alt),
        title: Text('Reset status ${machine.name}?'),
        content: const Text('Perintah reset status GANGGUAN dikirim ke mesin. Pastikan penyebab gangguan sudah ditangani.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(repositoryProvider).resetMachine(machine.id);
      ref.invalidate(machinesProvider);
      if (context.mounted) showSnack(context, 'Perintah reset dikirim ke ${machine.name}');
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final canReset = machine.status == MachineStatus.gangguan;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: 'Kontrol Perbaikan', icon: Icons.warning_amber_rounded),
          Material(
            color: canReset ? p.errorSoft : p.cardMuted,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: canReset ? () => _reset(context, ref) : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.restart_alt, color: canReset ? p.error : p.textMuted, size: 30),
                    const SizedBox(height: 6),
                    Text('Reset Status Gangguan', style: context.text.labelLarge?.copyWith(color: canReset ? p.error : p.textMuted)),
                    Text(
                      canReset ? 'Kirim perintah ke mesin' : 'Mesin tidak dalam status Gangguan',
                      style: context.text.bodySmall?.copyWith(color: canReset ? p.error : p.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryLog extends ConsumerWidget {
  const _TelemetryLog({required this.machineId});
  final String machineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final logs = ref.watch(telemetryProvider(machineId));
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Log Telemetri',
            icon: Icons.history,
            trailing: StatusPill(label: 'Live', dot: true),
          ),
          switch (logs) {
            AsyncValue(:final value?) => Column(
              children: [
                for (final l in value)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          switch (l.kind) {
                            'rfid' => Icons.contactless_outlined,
                            'servo' => Icons.swap_horiz,
                            _ => Icons.sensors,
                          },
                          size: 18,
                          color: p.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.title, style: context.text.labelLarge?.copyWith(color: p.textSecondary)),
                              Text(
                                l.detail,
                                style: context.text.bodySmall?.copyWith(color: p.textMuted, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          Fmt.timeWithSeconds(l.time).replaceAll(' WIB', ''),
                          style: context.text.labelSmall?.copyWith(color: p.textMuted, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(telemetryProvider(machineId))),
            _ => const SkeletonList(count: 2),
          },
        ],
      ),
    );
  }
}
