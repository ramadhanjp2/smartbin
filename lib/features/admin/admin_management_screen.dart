import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

class AdminManagementScreen extends ConsumerStatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  ConsumerState<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends ConsumerState<AdminManagementScreen> {
  int _tab = 0;
  final _search = TextEditingController();
  final List<_ManagedUser> _users = const [
    _ManagedUser('USR-001', 'Ahmad Fauzi', 'ahmad@smartbin.id', 'Mahasiswa', true),
    _ManagedUser('USR-002', 'Siti Nurhaliza', 'siti@smartbin.id', 'Mahasiswa', true),
    _ManagedUser('USR-003', 'Budi Santoso', 'budi@smartbin.id', 'Petugas', true),
    _ManagedUser('USR-004', 'Dewi Lestari', 'dewi@smartbin.id', 'Mahasiswa', false),
  ];
  final List<_AdminHistory> _history = const [
    _AdminHistory('TX-24001', 'USR-001', 'SmartBIN A-01', 'Organik', 2.40, 240, '29 Okt 2026 16:20'),
    _AdminHistory('TX-24002', 'USR-002', 'SmartBIN B-03', 'Anorganik', 1.15, 115, '29 Okt 2026 15:42'),
    _AdminHistory('TX-24003', 'USR-003', 'SmartBIN A-01', 'Anorganik', 3.05, 305, '29 Okt 2026 14:18'),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final machines = ref.watch(machinesProvider);
    return Scaffold(
      appBar: const SmartbinAppBar(title: 'Manajemen Admin', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in const <({int index, String label, IconData icon})>[
                (index: 0, label: 'Ringkasan', icon: Icons.analytics_outlined),
                (index: 1, label: 'Pengguna', icon: Icons.people_alt_outlined),
                (index: 2, label: 'Mesin', icon: Icons.precision_manufacturing_outlined),
                (index: 3, label: 'History All', icon: Icons.history),
              ])
                ChoiceChip(
                  selected: item.index == _tab,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _tab = item.index),
                  label: Text(item.label),
                  avatar: Icon(item.icon, size: 18, color: item.index == _tab ? Colors.white : p.textMuted),
                  selectedColor: p.brand,
                  labelStyle: TextStyle(color: item.index == _tab ? Colors.white : p.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 16),
          switch (_tab) {
            0 => _Summary(machines: machines.value ?? const []),
            1 => _Users(users: _users, search: _search),
            2 => _MachineManagement(machines: machines.value ?? const []),
            _ => _HistoryAll(history: _history, search: _search),
          },
        ],
      ),
    );
  }
}

class _ManagedUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool active;
  const _ManagedUser(this.id, this.name, this.email, this.role, this.active);
}

class _AdminHistory {
  final String id;
  final String userId;
  final String machine;
  final String type;
  final double kg;
  final int points;
  final String time;
  const _AdminHistory(this.id, this.userId, this.machine, this.type, this.kg, this.points, this.time);
}

class _Summary extends StatelessWidget {
  const _Summary({required this.machines});
  final List<Machine> machines;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final online = machines.where((m) => m.status != MachineStatus.offline).length;
    final avgOrganic = machines.isEmpty ? 0 : machines.map((m) => m.organicFill).reduce((a, b) => a + b) ~/ machines.length;
    final avgInorganic = machines.isEmpty ? 0 : machines.map((m) => m.inorganicFill).reduce((a, b) => a + b) ~/ machines.length;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(icon: Icons.sensors, color: p.brand, label: 'Mesin Online', value: '$online'),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: _StatTile(icon: Icons.people, color: Colors.blue, label: 'Pengguna Aktif', value: '128'),
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
                    child: _Gauge(label: 'Organik', value: avgOrganic, color: Colors.green),
                  ),
                  Expanded(
                    child: _Gauge(label: 'Anorganik', value: avgInorganic, color: Colors.orange),
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
              SectionHeader(title: 'Tren Setoran Hari Ini', icon: Icons.show_chart),
              const SizedBox(height: 12),
              _MiniChart(values: const [18, 32, 26, 48, 41, 62, 55, 74], color: p.brand),
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
      Text(label),
    ],
  );
}

class _MiniChart extends StatelessWidget {
  const _MiniChart({required this.values, required this.color});
  final List<int> values;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 120,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final value in values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                height: value * 1.15,
                decoration: BoxDecoration(color: color.withValues(alpha: .75), borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Users extends StatefulWidget {
  const _Users({required this.users, required this.search});
  final List<_ManagedUser> users;
  final TextEditingController search;
  @override
  State<_Users> createState() => _UsersState();
}

class _UsersState extends State<_Users> {
  @override
  Widget build(BuildContext context) {
    final query = widget.search.text.toLowerCase();
    final filtered = widget.users.where((u) => '${u.name} ${u.email} ${u.id}'.toLowerCase().contains(query)).toList();
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
        onPressed: () => _configure(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Tambah / Konfigurasi Mesin'),
      ),
      const SizedBox(height: 12),
      for (final machine in machines)
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
    final location = TextEditingController(text: machine?.location ?? 'Lokasi kampus');
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
    if (ok == true) {
      ref.read(sharedPrefsProvider).setString('machine_name_${machine?.id ?? 'new'}', name.text);
      ref.read(sharedPrefsProvider).setString('machine_location_${machine?.id ?? 'new'}', location.text);
      ref.read(sharedPrefsProvider).setString('machine_telemetry_interval', interval.text);
      if (context.mounted) showSnack(context, 'Konfigurasi mesin tersimpan');
    }
  }
}

class _HistoryAll extends StatefulWidget {
  const _HistoryAll({required this.history, required this.search});
  final List<_AdminHistory> history;
  final TextEditingController search;
  @override
  State<_HistoryAll> createState() => _HistoryAllState();
}

class _HistoryAllState extends State<_HistoryAll> {
  @override
  Widget build(BuildContext context) {
    final query = widget.search.text.toLowerCase();
    final filtered = widget.history.where((h) => '${h.id} ${h.userId} ${h.machine} ${h.type}'.toLowerCase().contains(query)).toList();
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
              subtitle: Text('${item.userId} • ${item.machine}\n${item.kg} kg • ${item.points} poin • ${item.time}'),
              isThreeLine: true,
              trailing: Text(item.type),
            ),
          ),
      ],
    );
  }

  Future<void> _exportCsv(BuildContext context, List<_AdminHistory> rows) async {
    const header = 'ID Transaksi,ID Pengguna,Mesin,Jenis,Berat kg,Poin,Waktu';
    final data = rows.map((h) => '${h.id},${h.userId},${h.machine},${h.type},${h.kg},${h.points},${h.time}').join('\n');
    await Clipboard.setData(ClipboardData(text: '$header\n$data'));
    if (context.mounted) showSnack(context, 'CSV disalin ke clipboard (${rows.length} baris)');
  }
}
