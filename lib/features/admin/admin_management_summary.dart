part of 'admin_management_screen.dart';

class _Summary extends ConsumerWidget {
  const _Summary({required this.machines});
  final List<Machine> machines;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final machine = machines.isEmpty ? null : machines.first;
    final organic = machine?.organicFill ?? 0;
    final inorganic = machine?.inorganicFill ?? 0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(icon: Icons.sensors, color: p.brand, label: 'Status Mesin', value: machine?.status.label ?? 'Tidak ada'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.people,
                color: Colors.blue,
                label: 'Pengguna Aktif',
                value: '${ref.watch(adminUsersProvider).value?.where((u) => u.active).length ?? 0}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: 'Visualisasi Kapasitas', icon: Icons.donut_large_outlined),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Gauge(label: 'Organik', value: organic, color: Colors.green),
                  ),
                  Expanded(
                    child: _Gauge(label: 'Anorganik', value: inorganic, color: Colors.orange),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            children: [
              SectionHeader(title: 'Berat Sampah per Hari', icon: Icons.show_chart),
              const SizedBox(height: 12),
              _MiniChart(
                values: [for (final day in ref.watch(adminDailyWeightsProvider).value ?? const <DailyWeight>[]) day.weightKg],
                color: p.brand,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.color, required this.label, required this.value});
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SectionCard(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text(label, style: context.text.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Gauge extends StatelessWidget {
  const _Gauge({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0, 100);
    return Column(
      children: [
        SizedBox(
          height: 118,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 118,
                height: 118,
                child: CircularProgressIndicator(
                  value: safeValue / 100,
                  strokeWidth: 12,
                  backgroundColor: color.withValues(alpha: .12),
                  color: color,
                ),
              ),
              Text('$safeValue%', style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        Text(
          safeValue >= 90
              ? 'Kritis / penuh'
              : safeValue >= 75
              ? 'Perlu diangkat'
              : 'Kapasitas aman',
          style: context.text.bodySmall?.copyWith(
            color: safeValue >= 90
                ? context.palette.error
                : safeValue >= 75
                ? context.palette.warning
                : context.palette.success,
          ),
        ),
      ],
    );
  }
}

class _MiniChart extends StatelessWidget {
  const _MiniChart({required this.values, required this.color});
  final List<double> values;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, (max, value) => value > max ? value : max);
    final now = Fmt.dateOnlyWib(DateTime.now());
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < values.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${values[index].toStringAsFixed(values[index] % 1 == 0 ? 0 : 1)} kg',
                      style: context.text.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: maxValue == 0 ? 4 : 100 * (values[index] / maxValue),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: values[index] == 0 ? .18 : .85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('E', 'id_ID').format(now.subtract(Duration(days: 6 - index))),
                      style: context.text.labelSmall?.copyWith(color: context.palette.textMuted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
