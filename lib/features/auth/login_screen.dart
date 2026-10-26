import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../state/providers.dart';
import 'auth_widgets.dart';

/// S02 – Login.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.message});

  /// Pesan penjelasan, mis. saat sesi habis.
  final String? message;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _admin = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(_id.text, _pw.text, asAdmin: _admin);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: EyebrowAppBar(
        eyebrow: 'SmartBIN',
        title: 'Login',
        trailing: CircleAvatar(
          backgroundColor: p.brandDark,
          child: const Icon(Icons.person_outline, color: Colors.white),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const AuthHero(icon: Icons.recycling, title: 'Selamat Datang!', subtitle: 'Kelola sampah pintar & kumpulkan poin KTM'),
            const SizedBox(height: 20),
            _RoleToggle(admin: _admin, onChanged: (v) => setState(() => _admin = v)),
            const SizedBox(height: 16),
            if (widget.message != null) ...[
              AuthNotice(icon: Icons.info_outline, title: 'Sesi berakhir', body: widget.message!, tone: PillTone.warning),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              AuthNotice(icon: Icons.gpp_maybe_outlined, title: 'Gagal masuk', body: _error!, tone: PillTone.error),
              const SizedBox(height: 16),
            ] else ...[
              const AuthNotice(
                icon: Icons.shield_outlined,
                title: 'Proteksi Keamanan Aktif',
                body: 'Gagal 5× berturut-turut akan mengunci login sementara selama 5 menit.',
                tone: PillTone.success,
              ),
              const SizedBox(height: 16),
            ],
            SectionCard(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FieldLabel(_admin ? 'Email Admin' : 'NIM atau Email Kampus'),
                      TextFormField(
                        controller: _id,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        decoration: InputDecoration(
                          hintText: _admin ? 'admin@smartbin.id' : 'Masukkan NIM atau email kampus',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          fillColor: p.cardMuted,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(child: FieldLabel('Kata Sandi')),
                          TextButton(
                            onPressed: () => showSnack(context, 'Reset kata sandi lewat email tersedia di Rilis 2. Hubungi admin kampus.'),
                            child: const Text('Lupa Sandi?'),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: _pw,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: 'Masukkan kata sandi akun',
                          prefixIcon: const Icon(Icons.lock_outline),
                          fillColor: p.cardMuted,
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Tampilkan sandi' : 'Sembunyikan sandi',
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                            : const Row(mainAxisSize: MainAxisSize.min, children: [Text('Masuk ke Akun'), SizedBox(width: 8), Icon(Icons.login)]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _DemoHint(admin: _admin),
            const SizedBox(height: 16),
            if (!_admin)
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Belum punya akun?', style: context.text.bodyMedium?.copyWith(color: p.textMuted)),
                  TextButton(onPressed: () => context.push('/register'), child: const Text('Daftar Sekarang')),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              'Green Campus Initiative · Terintegrasi dengan Sensor IoT SmartBIN',
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: p.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleToggle extends StatelessWidget {
  const _RoleToggle({required this.admin, required this.onChanged});
  final bool admin;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget seg(String label, IconData icon, bool selected, VoidCallback onTap) => Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48,
            decoration: BoxDecoration(color: selected ? p.brand : Colors.transparent, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: selected ? Colors.white : p.textSecondary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label, style: context.text.labelLarge?.copyWith(color: selected ? Colors.white : p.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          seg('Mahasiswa', Icons.school_outlined, !admin, () => onChanged(false)),
          seg('Admin / Teknisi', Icons.build_outlined, admin, () => onChanged(true)),
        ],
      ),
    );
  }
}

class _DemoHint extends StatelessWidget {
  const _DemoHint({required this.admin});
  final bool admin;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.cardMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: p.textMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              admin ? 'Mode demo · admin@smartbin.id / admin1234' : 'Mode demo · 2106728190 / smartbin123',
              style: context.text.bodySmall?.copyWith(color: p.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
