part of 'admin_management_screen.dart';

class _Users extends ConsumerStatefulWidget {
  const _Users({required this.users, required this.search, required this.loading, this.error});
  final List<AdminUserSummary> users;
  final TextEditingController search;
  final bool loading;
  final Object? error;
  @override
  ConsumerState<_Users> createState() => _UsersState();
}

class _UsersState extends ConsumerState<_Users> {
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
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _InfoChip(label: user.role == 'admin' ? 'Admin' : 'Pengguna'),
                      _InfoChip(label: user.active ? 'Aktif' : 'Nonaktif', color: user.active ? Colors.green : Colors.orange),
                    ],
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit pengguna')),
                  PopupMenuItem(value: 'toggle', child: Text(user.active ? 'Nonaktifkan' : 'Aktifkan')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Hapus pengguna', style: TextStyle(color: Colors.red)),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'edit') _editUser(context, user);
                  if (v == 'toggle') _toggleUser(context, user);
                  if (v == 'delete') _deleteUser(context, user);
                },
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addUser(BuildContext context) async {
    final nik = TextEditingController();
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    String role = 'user';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tambah pengguna'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nik,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'NIK (16 digit)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Peran'),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('Pengguna')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) => role = value ?? 'user',
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
    if (ok != true) return;
    try {
      await ref
          .read(repositoryProvider)
          .createAdminUser(nik: nik.text.trim(), name: name.text.trim(), email: email.text.trim(), password: password.text, role: role);
      ref.invalidate(adminUsersProvider);
      if (context.mounted) showSnack(context, 'Pengguna berhasil ditambahkan');
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
    }
  }

  Future<void> _editUser(BuildContext context, AdminUserSummary user) async {
    final name = TextEditingController(text: user.name);
    final email = TextEditingController(text: user.email);
    final password = TextEditingController();
    String role = user.role;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit pengguna'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password baru (opsional)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Peran'),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('Pengguna')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) => role = value ?? 'user',
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
    if (ok != true) return;
    try {
      await ref
          .read(repositoryProvider)
          .updateAdminUser(
            user.id,
            name: name.text.trim(),
            email: email.text.trim(),
            role: role,
            password: password.text.isEmpty ? null : password.text,
          );
      ref.invalidate(adminUsersProvider);
      if (context.mounted) showSnack(context, 'Pengguna berhasil diperbarui');
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
    }
  }

  Future<void> _toggleUser(BuildContext context, AdminUserSummary user) async {
    try {
      await ref.read(repositoryProvider).updateAdminUser(user.id, active: !user.active);
      ref.invalidate(adminUsersProvider);
      if (context.mounted) showSnack(context, user.active ? 'Pengguna dinonaktifkan' : 'Pengguna diaktifkan');
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
    }
  }

  Future<void> _deleteUser(BuildContext context, AdminUserSummary user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus pengguna?'),
        content: Text('${user.name} akan dihapus permanen dari database.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(repositoryProvider).deleteAdminUser(user.id);
      ref.invalidate(adminUsersProvider);
      if (context.mounted) showSnack(context, 'Pengguna berhasil dihapus');
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? context.palette.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: chipColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(color: chipColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}
