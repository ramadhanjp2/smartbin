import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

PillTone machineTone(MachineStatus s) => switch (s) {
  MachineStatus.idle => PillTone.success,
  MachineStatus.sibuk => PillTone.warning,
  MachineStatus.siap => PillTone.success,
  MachineStatus.penuh => PillTone.warning,
  MachineStatus.gangguan => PillTone.error,
  MachineStatus.offline => PillTone.neutral,
};

String machineStatusText(MachineStatus s) => switch (s) {
  MachineStatus.idle => 'Online & Siap Digunakan',
  MachineStatus.sibuk => 'Sedang Melayani Pengguna',
  MachineStatus.siap => 'Online & Siap Digunakan',
  MachineStatus.penuh => 'Tong Penuh',
  MachineStatus.gangguan => 'Gangguan',
  MachineStatus.offline => 'Offline',
};

/// S08 – Daftar mesin dan status.
class MachinesScreen extends ConsumerWidget {
  const MachinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final machines = ref.watch(machinesProvider);
    final visibleMachines = machines.value?.take(1).toList();
    final online = visibleMachines?.where((m) => m.status != MachineStatus.offline).length;

    return Scaffold(
      appBar: const SmartbinAppBar(title: 'Mesin'),
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
            Text('Status Mesin SmartBIN', style: context.text.headlineLarge?.copyWith(color: p.textPrimary)),
            const SizedBox(height: 4),
            Text('Pemantauan status operasional & sensor mesin', style: context.text.bodyMedium?.copyWith(color: p.textMuted)),
            if (online != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(label: '$online dari ${visibleMachines!.length} unit online', dot: true),
              ),
            ],
            const SizedBox(height: 16),
            switch (machines) {
              AsyncValue(:final value?) when value.isEmpty => const EmptyView(
                icon: Icons.delete_sweep_outlined,
                title: 'Belum ada mesin',
                message: 'Mesin SmartBIN belum tersedia.',
              ),
              AsyncValue(:final value?) => Column(
                children: [
                  for (final m in value.take(1))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: MachineCard(machine: m),
                    ),
                ],
              ),
              AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(machinesProvider)),
              _ => const SkeletonList(count: 3),
            },
            const _QuickGuide(),
            const SizedBox(height: 16),
            SectionCard(
              padding: const EdgeInsets.all(16),
              onTap: () => showSnack(context, 'Laporan gangguan dikirim ke admin SmartBIN.'),
              child: Row(
                children: [
                  IconTile(icon: Icons.support_agent, background: p.warningSoft, foreground: p.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Punya kendala pada mesin?', style: context.text.titleMedium?.copyWith(color: p.textSecondary)),
                        Text('Laporkan gangguan ke admin SmartBIN.', style: context.text.bodySmall?.copyWith(color: p.textMuted)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: p.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MachineCard extends StatelessWidget {
  const MachineCard({super.key, required this.machine});
  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = machine;
    final offline = m.status == MachineStatus.offline;
    final okModules = m.modules.where((x) => x.ok).length;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: Icons.sensors, size: 52, background: offline ? p.cardMuted : p.accentSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: context.text.headlineSmall?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              StatusPill(label: m.status.label, tone: machineTone(m.status), dot: true),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: p.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  offline ? 'Terakhir terlihat ${Fmt.ago(m.lastSeen, DateTime.now())}' : 'Heartbeat: ${Fmt.ago(m.lastSeen, DateTime.now())}',
                  style: context.text.bodySmall?.copyWith(color: offline ? p.warning : p.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (offline)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(14)),
              child: Text(
                'Mesin sedang offline dan menolak sesi baru. Coba kembali setelah koneksi pulih.',
                style: context.text.bodySmall?.copyWith(color: p.textMuted),
              ),
            )
          else ...[
            Row(
              children: [
                Text('Kapasitas Kompartemen', style: context.text.labelLarge?.copyWith(color: p.textSecondary)),
                const Spacer(),
                Text('Modul $okModules/${m.modules.length} normal', style: context.text.labelMedium?.copyWith(color: p.success)),
              ],
            ),
            const SizedBox(height: 10),
            _BinRow(
              title: 'Tong Organik',
              hint: 'Sisa makanan, daun, kertas basah',
              icon: Icons.compost,
              percent: m.organicFill,
              cmLeft: m.organicCmLeft,
            ),
            const SizedBox(height: 10),
            _BinRow(
              title: 'Tong Anorganik',
              hint: 'Botol plastik, kaleng, cup minuman',
              icon: Icons.recycling,
              percent: m.inorganicFill,
              cmLeft: m.inorganicCmLeft,
            ),
            const SizedBox(height: 10),
            _BinRow(
              title: 'Tong Residu',
              hint: 'Sampah campuran, logam, atau hasil klasifikasi tidak pasti',
              icon: Icons.delete_outline,
              percent: m.residuFill,
              cmLeft: m.residuCmLeft,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mod in m.modules)
                  StatusPill(
                    label: '${mod.name} · ${mod.detail}',
                    tone: mod.ok ? PillTone.neutral : PillTone.error,
                    icon: mod.ok ? Icons.check_circle_outline : Icons.error_outline,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BinRow extends StatelessWidget {
  const _BinRow({required this.title, required this.hint, required this.icon, required this.percent, required this.cmLeft});
  final String title, hint;
  final IconData icon;
  final int percent, cmLeft;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final full = percent >= 90;
    final color = FillBar.fillColor(context, percent);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            children: [
              IconTile(icon: icon, size: 36, background: p.accentSoft),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.labelLarge?.copyWith(color: p.textPrimary)),
                    Text(hint, style: context.text.bodySmall?.copyWith(color: p.textMuted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$percent%',
                    style: context.text.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w800),
                  ),
                  Text(full ? 'Penuh' : (percent >= 75 ? 'Hampir Penuh' : 'Kapasitas Aman'), style: context.text.labelSmall?.copyWith(color: color)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: '$title terisi $percent persen',
            child: FillBar(percent: percent),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Jarak sensor ke permukaan: $cmLeft cm',
              style: context.text.labelSmall?.copyWith(color: p.textMuted, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickGuide extends StatelessWidget {
  const _QuickGuide();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const steps = [
      ('Tempelkan KTP', 'Dekatkan KTP fisik ke modul pembaca kartu mesin sampai bunyi bip.'),
      ('Masukkan sampah', 'Masukkan satu sampah melalui lubang setelah mesin menyatakan siap.'),
      ('Pemilahan otomatis', 'Sensor berat, induktif, dan AI menentukan kategori dan tujuan sampah.'),
      ('Poin dari server', 'Backend menghitung poin dan menyinkronkan setoran ke akun Anda. Residu tidak mendapat poin.'),
    ];
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Panduan Penggunaan Cepat', icon: Icons.help_outline),
          for (var i = 0; i < steps.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(14)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: p.brandDark,
                    child: Text('${i + 1}', style: context.text.labelMedium?.copyWith(color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].$1, style: context.text.labelLarge?.copyWith(color: p.textSecondary)),
                        Text(steps[i].$2, style: context.text.bodySmall?.copyWith(color: p.textMuted)),
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
