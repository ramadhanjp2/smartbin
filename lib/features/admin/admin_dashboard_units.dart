part of 'admin_dashboard_screen.dart';

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
            const SizedBox(width: 12),
            bin('Residu', machine.residuFill, machine.residuCmLeft),
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
