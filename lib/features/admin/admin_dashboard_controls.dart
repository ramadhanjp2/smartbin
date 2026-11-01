part of 'admin_dashboard_screen.dart';

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
      await ref.read(repositoryProvider).resetMachine(machine.deviceId);
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
