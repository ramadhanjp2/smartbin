import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../machines/machines_screen.dart';

/// S10 – Daftar notifikasi.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final machines = ref.watch(machinesProvider);

    return Scaffold(
      appBar: const SmartbinAppBar(title: 'Notifikasi', showBack: true),
      body: RefreshIndicator(
        color: p.brand,
        onRefresh: () async {
          ref.invalidate(machinesProvider);
          try {
            await ref.read(machinesProvider.future);
          } catch (_) {}
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text('Status Mesin', style: context.text.headlineLarge?.copyWith(color: p.textPrimary)),
            const SizedBox(height: 12),
            Text('Pantau kondisi mesin dan kapasitas setiap tong secara langsung.', style: context.text.bodyMedium?.copyWith(color: p.textMuted)),
            const SizedBox(height: 16),
            switch (machines) {
              AsyncValue(:final value?) => () {
                if (value.isEmpty) {
                  return const EmptyView(
                    icon: Icons.notifications_none,
                    title: 'Mesin belum tersedia',
                    message: 'Status mesin dan kapasitas tong akan tampil di sini.',
                  );
                }
                return Column(
                  children: [
                    for (final machine in value.take(1))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MachineStatusCard(machine: machine),
                      ),
                  ],
                );
              }(),
              AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(machinesProvider)),
              _ => const SkeletonList(count: 4),
            },
          ],
        ),
      ),
    );
  }
}

class _MachineStatusCard extends StatelessWidget {
  const _MachineStatusCard({required this.machine});
  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: Icons.sensors, size: 48, background: p.accentSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(machine.name, style: context.text.titleLarge?.copyWith(color: p.textPrimary)),
                    Text(machine.location, style: context.text.bodySmall?.copyWith(color: p.textMuted)),
                  ],
                ),
              ),
              StatusPill(label: machine.status.label, tone: machineTone(machine.status), dot: true),
            ],
          ),
          const SizedBox(height: 16),
          _CapacityRow(title: 'Anorganik', percent: machine.inorganicFill, icon: Icons.recycling, color: p.success),
          const SizedBox(height: 10),
          _CapacityRow(title: 'Organik', percent: machine.organicFill, icon: Icons.eco_outlined, color: p.brand),
          const SizedBox(height: 10),
          _CapacityRow(title: 'Residu', percent: machine.residuFill, icon: Icons.delete_outline, color: p.warning),
        ],
      ),
    );
  }
}

class _CapacityRow extends StatelessWidget {
  const _CapacityRow({required this.title, required this.percent, required this.icon, required this.color});
  final String title;
  final int percent;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          IconTile(icon: icon, size: 38, background: p.card, foreground: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.labelLarge?.copyWith(color: p.textPrimary)),
                const SizedBox(height: 5),
                FillBar(percent: percent, color: color),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$percent%',
            style: context.text.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
