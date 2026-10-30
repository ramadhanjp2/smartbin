import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

class AdminManagementScreen extends ConsumerStatefulWidget {
  const AdminManagementScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends ConsumerState<AdminManagementScreen> {
  late int _tab;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final machines = ref.watch(machinesProvider);
    final users = ref.watch(adminUsersProvider);
    final history = ref.watch(adminHistoryProvider);
    return Scaffold(
      appBar: const SmartbinAppBar(title: 'Manajemen Admin', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SizedBox(height: 4),
          switch (_tab) {
            0 => _Summary(machines: machines.value ?? const []),
            1 => switch (users) {
              AsyncValue(:final value?) => _Users(users: value, loading: false, search: _search),
              AsyncValue(:final error?) => _Users(users: const [], loading: false, error: error, search: _search),
              _ => _Users(users: const [], loading: true, search: _search),
            },
            2 => _MachineManagement(machines: machines.value ?? const []),
            _ => switch (history) {
              AsyncValue(:final value?) => _HistoryAll(history: value, loading: false, search: _search),
              AsyncValue(:final error?) => _HistoryAll(history: const [], loading: false, error: error, search: _search),
              _ => _HistoryAll(history: const [], loading: true, search: _search),
            },
          },
        ],
      ),
    );
  }
}

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
              child: FutureBuilder<List<AdminUserSummary>>(
                future: ref.read(repositoryProvider).adminUsers(),
                builder: (_, snapshot) => _StatTile(
                  icon: Icons.people,
                  color: Colors.blue,
                  label: 'Pengguna Aktif',
                  value: '${snapshot.data?.where((u) => u.active).length ?? 0}',
                ),
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
              FutureBuilder<List<AdminHistoryRecord>>(
                future: ref.read(repositoryProvider).adminHistory(),
                builder: (_, snapshot) {
                  final rows = snapshot.data ?? const <AdminHistoryRecord>[];
                  final totals = <int, double>{};
                  for (final row in rows) {
                    final key = row.time.toLocal().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
                    totals[key] = (totals[key] ?? 0) + row.weightKg;
                  }
                  final now = DateTime.now();
                  final values = List.generate(7, (index) {
                    final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - index));
                    final key = DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
                    return totals[key] ?? 0;
                  });
                  return _MiniChart(values: values, color: p.brand);
                },
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
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 118,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 118,
              height: 118,
              child: CircularProgressIndicator(value: value / 100, strokeWidth: 12, backgroundColor: color.withValues(alpha: .12), color: color),
            ),
            Text('$value%', style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Text(label, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      Text(
        value >= 90
            ? 'Kritis / penuh'
            : value >= 75
            ? 'Perlu diangkat'
            : 'Kapasitas aman',
        style: context.text.bodySmall?.copyWith(
          color: value >= 90
              ? context.palette.error
              : value >= 75
              ? context.palette.warning
              : context.palette.success,
        ),
      ),
    ],
  );
}

class _MiniChart extends StatelessWidget {
  const _MiniChart({required this.values, required this.color});
  final List<double> values;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, (max, value) => value > max ? value : max);
    final now = DateTime.now();
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

class _Users extends StatefulWidget {
  const _Users({required this.users, required this.search, required this.loading, this.error});
  final List<AdminUserSummary> users;
  final TextEditingController search;
  final bool loading;
  final Object? error;
  @override
  State<_Users> createState() => _UsersState();
}

class _UsersState extends State<_Users> {
  @override
  Widget build(BuildContext context) {
    final query = widget.search.text.toLowerCase();
    final filtered = widget.users.where((u) => '${u.name} ${u.email} ${u.id}'.toLowerCase().contains(query)).toList();
    if (widget.loading) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
      );
    }
    if (widget.error != null) return ErrorView(error: widget.error!, onRetry: () => setState(() {}));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari nama, email, atau ID pengguna'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: () => _addUser(context), icon: const Icon(Icons.person_add_alt_1), label: const Text('Tambah Pengguna')),
        const SizedBox(height: 12),
        for (final user in filtered)
          SectionCard(
            padding: const EdgeInsets.all(12),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(user.name[0])),
              title: Text(user.name),
              subtitle: Text('${user.email}\n${user.role} • ${user.active ? 'Aktif' : 'Nonaktif'}'),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'toggle', child: Text('Aktifkan / Nonaktifkan')),
                ],
                onSelected: (v) => showSnack(context, v == 'edit' ? 'Form edit pengguna dibuka' : 'Status pengguna diperbarui'),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addUser(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tambah pengguna'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: 'Nama')),
            TextField(decoration: InputDecoration(labelText: 'Email')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok == true && context.mounted) showSnack(context, 'Pengguna berhasil ditambahkan');
  }
}

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
      for (final machine in machines.take(1))
        SectionCard(
          padding: const EdgeInsets.all(12),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: IconTile(icon: Icons.delete_sweep_outlined, size: 46),
            title: Text(machine.name),
            subtitle: Text('${machine.location}\n${machine.status.label} • Organik ${machine.organicFill}% • Anorganik ${machine.inorganicFill}%'),
            isThreeLine: true,
            trailing: IconButton(icon: const Icon(Icons.tune), tooltip: 'Konfigurasi', onPressed: () => _configure(context, ref, machine)),
          ),
        ),
    ],
  );

  Future<void> _configure(BuildContext context, WidgetRef ref, Machine? machine) async {
    final name = TextEditingController(text: machine?.name ?? 'SmartBIN Baru');
    final location = TextEditingController(text: machine?.location ?? 'Lokasi pemasangan');
    final interval = TextEditingController(text: ref.read(sharedPrefsProvider).getString('machine_telemetry_interval') ?? '60');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(machine == null ? 'Konfigurasi mesin' : 'Konfigurasi ${machine.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama mesin'),
              ),
              TextField(
                controller: location,
                decoration: const InputDecoration(labelText: 'Lokasi'),
              ),
              TextField(
                controller: interval,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Interval telemetry (detik)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok == true && machine != null) {
      try {
        await ref.read(repositoryProvider).configureMachine(machine.id, name: name.text.trim(), location: location.text.trim());
        ref.read(sharedPrefsProvider).setString('machine_telemetry_interval_${machine.id}', interval.text);
        ref.invalidate(machinesProvider);
        if (context.mounted) showSnack(context, 'Konfigurasi mesin tersimpan ke database');
      } catch (e) {
        if (context.mounted) showSnack(context, errorText(e));
      }
    }
  }
}

class _HistoryAll extends StatefulWidget {
  const _HistoryAll({required this.history, required this.search, required this.loading, this.error});
  final List<AdminHistoryRecord> history;
  final TextEditingController search;
  final bool loading;
  final Object? error;
  @override
  State<_HistoryAll> createState() => _HistoryAllState();
}

class _HistoryAllState extends State<_HistoryAll> {
  @override
  Widget build(BuildContext context) {
    final query = widget.search.text.toLowerCase();
    final filtered = widget.history.where((h) => '${h.id} ${h.userId} ${h.machine} ${h.type}'.toLowerCase().contains(query)).toList();
    if (widget.loading) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
      );
    }
    if (widget.error != null) return ErrorView(error: widget.error!, onRetry: () => setState(() {}));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari transaksi, pengguna, mesin, atau jenis sampah'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _exportCsv(context, filtered),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Export CSV'),
        ),
        const SizedBox(height: 12),
        for (final item in filtered)
          SectionCard(
            padding: const EdgeInsets.all(12),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Icon(item.type == 'Organik' ? Icons.compost : Icons.recycling)),
              title: Text(item.id),
              subtitle: Text(
                '${item.userId} • ${item.machine}\n${item.weightKg} kg • ${item.points} poin • ${DateFormat('d MMM yyyy HH:mm', 'id_ID').format(item.time.toLocal())}',
              ),
              isThreeLine: true,
              trailing: Text(item.type),
            ),
          ),
      ],
    );
  }

  Future<void> _exportCsv(BuildContext context, List<AdminHistoryRecord> rows) async {
    String csvValue(Object value) => '"${value.toString().replaceAll('"', '""')}"';
    const header = 'ID Transaksi,ID Pengguna,Mesin,Jenis,Berat kg,Poin,Waktu';
    final data = rows
        .map((h) => [h.id, h.userId, h.machine, h.type, h.weightKg, h.points, h.time.toIso8601String()].map(csvValue).join(','))
        .join('\n');
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/smartbin_history_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv');
      await file.writeAsString('$header\n$data', flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          text: 'Data history SmartBIN',
        ),
      );
      if (context.mounted) showSnack(context, 'CSV siap diekspor (${rows.length} baris)');
    } catch (e) {
      if (context.mounted) showSnack(context, 'CSV gagal diekspor: $e');
    }
  }
}
