import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// S11 – Profil.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final user = ref.watch(currentUserProvider);
    final summary = ref.watch(pointsSummaryProvider).value;
    final rates = ref.watch(ratesProvider);
    final themeMode = ref.watch(themeModeProvider);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: const SmartbinAppBar(title: 'Profil'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Identitas
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                UserAvatar(user: user, size: 96),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: context.text.headlineMedium?.copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(color: p.textMuted),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                  decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco_outlined, size: 16, color: p.textPrimary),
                      const SizedBox(width: 6),
                      Text('Level ${summary?.level ?? 1}', style: context.text.labelMedium?.copyWith(color: p.textPrimary)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          '${summary == null ? '–' : Fmt.points(summary.balance)} Poin',
                          style: context.text.labelMedium?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _KtmCard(user: user),
          const SizedBox(height: 16),

          // Poin & tarif
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: p.accentSoft,
                      child: Icon(Icons.paid_outlined, color: p.textPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Poin & Tarif Konversi', style: context.text.headlineSmall?.copyWith(color: p.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SALDO AKTIF PENGGUNA', style: context.text.labelSmall?.copyWith(color: p.textMuted)),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  summary == null ? '–' : Fmt.points(summary.balance),
                                  style: context.text.headlineLarge?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(width: 6),
                                Text('Poin SmartBIN', style: context.text.labelMedium?.copyWith(color: p.textPrimary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: p.accentSoft,
                        child: Icon(Icons.savings_outlined, color: p.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                switch (rates) {
                  AsyncValue(:final value?) => Row(
                    children: [
                      Expanded(
                        child: _RateTile(icon: Icons.inventory_2_outlined, label: 'Anorganik', value: value.anorganikPerKg, iconColor: p.warning),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RateTile(icon: Icons.compost, label: 'Organik', value: value.organikPerKg, iconColor: p.success),
                      ),
                    ],
                  ),
                  AsyncValue(hasError: true) => Text('Nilai poin belum bisa dimuat.', style: context.text.bodySmall?.copyWith(color: p.warning)),
                  _ => const Skeleton(height: 72, radius: 16),
                },
                const SizedBox(height: 12),
                Material(
                  color: p.cardMuted,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: Icon(Icons.menu_book_outlined, color: p.textPrimary),
                    title: Text('Panduan Pemilahan Sampah', style: context.text.labelLarge?.copyWith(color: p.textSecondary)),
                    subtitle: Text('Tersedia statis & bisa dibaca offline', style: context.text.bodySmall?.copyWith(color: p.textMuted)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/rates'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pengaturan
          SectionCard(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Pengaturan Akun & Aplikasi', style: context.text.headlineSmall?.copyWith(color: p.textSecondary)),
                ),
                const SizedBox(height: 8),
                if (user.role == UserRole.admin)
                  _SettingTile(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Dashboard Admin',
                    subtitle: 'Status mesin, tarif poin, reset',
                    onTap: () => context.push('/admin'),
                  ),
                _SettingTile(
                  icon: Icons.contactless,
                  title: 'Scan / Tautkan KTP',
                  subtitle: user.isCardLinked ? 'Kelola kartu NFC yang tertaut' : 'NFC aktif untuk menautkan KTP',
                  onTap: () => context.push('/link-ktp'),
                ),
                _SettingTile(icon: Icons.badge_outlined, title: 'Ubah Nama Profil', subtitle: user.name, onTap: () => _editName(context, ref, user)),
                _SettingTile(
                  icon: Icons.lock_reset,
                  title: 'Ganti Kata Sandi',
                  subtitle: 'Sesi di perangkat lain akan dicabut',
                  onTap: () => _changePassword(context, ref),
                ),
                _SettingTile(icon: Icons.palette_outlined, title: 'Preferensi Tema', subtitle: 'Tampilan antarmuka aplikasi'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, label: Text('Terang')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Gelap')),
                      ButtonSegment(value: ThemeMode.system, label: Text('Sistem')),
                    ],
                    selected: {themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: p.card,
                      selectedForegroundColor: p.textPrimary,
                      backgroundColor: p.cardMuted,
                      foregroundColor: p.textMuted,
                      side: BorderSide(color: p.border),
                    ),
                  ),
                ),
                SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor: p.cardMuted,
                    child: Icon(Icons.volume_up_outlined, color: p.textSecondary),
                  ),
                  title: Text('Notifikasi & Suara', style: context.text.labelLarge?.copyWith(color: p.textSecondary)),
                  subtitle: Text('Aktifkan peringatan setoran, mesin, dan KTP', style: context.text.bodySmall?.copyWith(color: p.textMuted)),
                  value: ref.watch(notificationSoundProvider),
                  onChanged: (v) => ref.read(notificationSoundProvider.notifier).set(v),
                ),
                SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor: p.cardMuted,
                    child: Icon(Icons.contactless, color: p.textSecondary),
                  ),
                  title: Text('NFC KTP', style: context.text.labelLarge?.copyWith(color: p.textSecondary)),
                  subtitle: Text(
                    'Aktifkan pemindaian kartu saat menggunakan menu Scan KTP',
                    style: context.text.bodySmall?.copyWith(color: p.textMuted),
                  ),
                  value: ref.watch(nfcEnabledProvider),
                  onChanged: (v) => ref.read(nfcEnabledProvider.notifier).set(v),
                ),
                _SettingTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Kebijakan Privasi & Ketentuan',
                  subtitle: 'UU No. 27 Tahun 2022 (PDP)',
                  onTap: () => _privacy(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: p.errorSoft, foregroundColor: p.error),
            onPressed: () => _logout(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Keluar dari Akun'),
          ),
          const SizedBox(height: 12),
          Text(
            'SmartBIN v1.0.0 • Rilis 1 (MVP)',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: p.textMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, AppUser user) async {
    final ctrl = TextEditingController(text: user.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Nama Profil'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nama lengkap', prefixIcon: Icon(Icons.person_outline)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Simpan')),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == user.name || !context.mounted) return;
    try {
      await ref.read(authProvider.notifier).updateName(name);
      if (context.mounted) showSnack(context, 'Nama berhasil diperbarui');
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
    }
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _ChangePasswordDialog());
    if (ok == true && context.mounted) showSnack(context, 'Kata sandi berhasil diganti');
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout),
        title: const Text('Keluar dari akun?'),
        content: const Text('Token di perangkat ini akan dihapus dan data tersimpan dibersihkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (ok == true) await ref.read(authProvider.notifier).logout();
  }

  void _privacy(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kebijakan Privasi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            SizedBox(height: 12),
            Text(
              '• Data yang disimpan: hash HMAC NIK, nama, email, dan riwayat setoran.\n'
              '• NIK dan UID KTP tidak disimpan dalam bentuk asli; server menyimpan hash HMAC berkunci.\n'
              '• Aplikasi tidak meminta lokasi, kontak, atau kamera.\n'
              '• Hapus akun menganonimkan riwayat setoran dan menghapus data pribadi.\n'
              '• Jangan meminjamkan KTP untuk menyetor sampah.\n\n'
              'Rujukan: UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi.',
              style: TextStyle(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _KtmCard extends ConsumerWidget {
  const _KtmCard({required this.user});
  final AppUser user;

  Future<void> _unlink(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _UnlinkDialog());
    if (ok == true && context.mounted) showSnack(context, 'Tautan KTP dilepas. Saldo poin Anda tetap.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final card = user.card;
    final soft = Colors.white.withValues(alpha: 0.75);
    Widget infoBox(String label, IconData icon, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.text.labelMedium?.copyWith(color: soft)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(value, style: context.text.labelLarge?.copyWith(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(
        children: [
          Positioned(right: -30, bottom: -30, child: Icon(Icons.contactless_outlined, size: 160, color: Colors.white.withValues(alpha: 0.07))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.credit_card, color: soft, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('KARTU TANDA PENDUDUK', style: context.text.labelMedium?.copyWith(color: soft, letterSpacing: 1)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: card != null ? p.accentSoft : const Color(0xFFFFE0B2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        card != null ? '● KTP Tertaut' : '● Belum Tertaut',
                        style: context.text.labelMedium?.copyWith(
                          color: card != null ? const Color(0xFF1B5E20) : const Color(0xFFE65100),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  user.email,
                  style: context.text.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                if (card != null) ...[
                  Row(
                    children: [
                      infoBox('RFID Hash (HMAC)', Icons.lock_outline, '**** - ${card.uidHashSuffix}'),
                      const SizedBox(width: 10),
                      infoBox('Tanggal Tertaut', Icons.event_available, Fmt.date(card.linkedAt)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    onPressed: () => _unlink(context, ref),
                    icon: const Icon(Icons.link_off),
                    label: const Text('Ganti / Lepas Tautan KTP'),
                  ),
                ] else ...[
                  Text('Tautkan KTP agar setiap setoran langsung masuk ke saldo Anda.', style: context.text.bodySmall?.copyWith(color: soft)),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: p.accentSoft, foregroundColor: const Color(0xFF1B5E20)),
                    onPressed: () => context.push('/link-ktp'),
                    icon: const Icon(Icons.contactless),
                    label: const Text('Tautkan KTP Sekarang'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({required this.icon, required this.label, required this.value, required this.iconColor});
  final IconData icon;
  final String label;
  final int value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(label, style: context.text.labelLarge?.copyWith(color: p.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$value', style: context.text.headlineMedium?.copyWith(color: p.textSecondary)),
              const SizedBox(width: 4),
              Text('Poin/kg', style: context.text.bodySmall?.copyWith(color: p.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.icon, required this.title, required this.subtitle, this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: CircleAvatar(
        backgroundColor: p.cardMuted,
        child: Icon(icon, color: p.textSecondary),
      ),
      title: Text(title, style: context.text.labelLarge?.copyWith(color: p.textSecondary)),
      subtitle: Text(
        subtitle,
        style: context.text.bodySmall?.copyWith(color: p.textMuted),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: onTap == null ? null : Icon(Icons.chevron_right, color: p.textMuted),
      onTap: onTap,
    );
  }
}

class _UnlinkDialog extends ConsumerStatefulWidget {
  const _UnlinkDialog();

  @override
  ConsumerState<_UnlinkDialog> createState() => _UnlinkDialogState();
}

class _UnlinkDialogState extends ConsumerState<_UnlinkDialog> {
  final _pw = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).unlinkCard(_pw.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.link_off),
      title: const Text('Lepas tautan KTP?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Setoran dengan KTP lama tidak lagi masuk ke akun ini. Saldo poin Anda tidak berubah.'),
          const SizedBox(height: 16),
          TextField(
            controller: _pw,
            obscureText: true,
            decoration: InputDecoration(hintText: 'Kata sandi akun', prefixIcon: const Icon(Icons.lock_outline), errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lepas KTP'),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  String? _oldError, _newError;
  bool _busy = false;

  Future<void> _submit() async {
    final pw = _new.text;
    final valid = pw.length >= 8 && RegExp('[A-Za-z]').hasMatch(pw) && RegExp('[0-9]').hasMatch(pw);
    setState(() {
      _oldError = null;
      _newError = valid ? null : 'Min. 8 karakter berisi huruf dan angka';
    });
    if (!valid) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).changePassword(oldPassword: _old.text, newPassword: pw);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _oldError = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ganti Kata Sandi'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _old,
            obscureText: true,
            decoration: InputDecoration(hintText: 'Kata sandi lama', errorText: _oldError),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _new,
            obscureText: true,
            decoration: InputDecoration(hintText: 'Kata sandi baru', errorText: _newError),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
        TextButton(onPressed: _busy ? null : _submit, child: const Text('Simpan')),
      ],
    );
  }
}
