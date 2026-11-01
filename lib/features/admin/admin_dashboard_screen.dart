import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../machines/machines_screen.dart';

part 'admin_dashboard_units.dart';
part 'admin_dashboard_controls.dart';

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
                                    MachineStatus.idle => p.success,
                                    MachineStatus.sibuk => p.warning,
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
                    _TelemetryLog(machineId: selected.deviceId),
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
