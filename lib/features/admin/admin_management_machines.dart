part of 'admin_management_screen.dart';

class _MachineManagement extends ConsumerWidget {
  const _MachineManagement({required this.machines});
  final List<Machine> machines;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: machines.isEmpty ? null : () => _configure(context, ref, machines.first),
        icon: const Icon(Icons.tune),
        label: const Text('Konfigurasi Mesin'),
      ),
      const SizedBox(height: 12),
      if (machines.isEmpty)
        const SectionCard(child: Text('Mesin belum tersedia pada database. Setelah backend dijalankan ulang, mesin utama akan dibuat otomatis.')),
      for (final machine in machines.take(1))
        SectionCard(
          padding: const EdgeInsets.all(12),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: IconTile(icon: Icons.delete_sweep_outlined, size: 46),
            title: Text(machine.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${machine.location}\n${machine.status.label} • Organik ${machine.organicFill}% • Anorganik ${machine.inorganicFill}% • Residu ${machine.residuFill}%',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            trailing: IconButton(icon: const Icon(Icons.tune), tooltip: 'Konfigurasi', onPressed: () => _configure(context, ref, machine)),
          ),
        ),
    ],
  );

  Future<void> _configure(BuildContext context, WidgetRef ref, Machine? machine) async {
    if (machine == null) return;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _MachineConfigDialog(
        machine: machine,
        interval: ref.read(sharedPrefsProvider).getString('machine_telemetry_interval_${machine.id}') ?? '60',
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(repositoryProvider).configureMachine(machine.id, name: result['name']!.trim(), location: result['location']!.trim());
      await ref.read(sharedPrefsProvider).setString('machine_telemetry_interval_${machine.id}', result['interval']!);
      ref.invalidate(machinesProvider);
      if (context.mounted) showSnack(context, 'Konfigurasi mesin tersimpan ke database');
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
    }
  }
}

class _MachineConfigDialog extends StatefulWidget {
  const _MachineConfigDialog({required this.machine, required this.interval});
  final Machine machine;
  final String interval;

  @override
  State<_MachineConfigDialog> createState() => _MachineConfigDialogState();
}

class _MachineConfigDialogState extends State<_MachineConfigDialog> {
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _interval;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.machine.name);
    _location = TextEditingController(text: widget.machine.location);
    _interval = TextEditingController(text: widget.interval);
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _interval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Konfigurasi mesin'),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Nama mesin', alignLabelWithHint: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Lokasi', alignLabelWithHint: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _interval,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Interval telemetry (detik)', alignLabelWithHint: true),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
      FilledButton(
        onPressed: () => Navigator.of(context).pop({
          'name': _name.text.trim(),
          'location': _location.text.trim(),
          'interval': _interval.text.trim().isEmpty ? '60' : _interval.text.trim(),
        }),
        child: const Text('Simpan'),
      ),
    ],
  );
}
