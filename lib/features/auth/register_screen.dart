import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import 'auth_widgets.dart';

/// S03 – Registrasi mahasiswa.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _nim = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _obscure = true;
  bool _agree = false;
  bool _busy = false;
  bool _showAgreeError = false;
  final Map<String, String> _serverErrors = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _pw.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_nim, _name, _email, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 0 = kosong, 1 = lemah, 2 = sedang, 3 = kuat.
  int get _strength {
    final pw = _pw.text;
    if (pw.isEmpty) return 0;
    var s = 0;
    if (pw.length >= 8) s++;
    if (RegExp('[A-Za-z]').hasMatch(pw) && RegExp('[0-9]').hasMatch(pw)) s++;
    if (pw.length >= 12 || RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) s++;
    return s.clamp(1, 3);
  }

  Future<void> _submit() async {
    setState(() {
      _serverErrors.clear();
      _error = null;
      _showAgreeError = !_agree;
    });
    if (!_form.currentState!.validate() || !_agree) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).register(nim: _nim.text.trim(), name: _name.text.trim(), email: _email.text.trim(), password: _pw.text);
    } on AppException catch (e) {
      setState(() {
        if (e.field != null) {
          _serverErrors[e.field!] = e.message;
          _form.currentState!.validate();
        } else {
          _error = e.message;
        }
      });
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final strength = _strength;
    final strengthLabel = ['Belum Diisi', 'Lemah', 'Sedang', 'Kuat'][strength];
    final strengthColor = [p.textMuted, p.error, p.warning, p.success][strength];

    return Scaffold(
      appBar: EyebrowAppBar(eyebrow: 'SmartBIN', title: 'Daftar', onBack: () => context.canPop() ? context.pop() : context.go('/login')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const AuthHero(
                icon: Icons.eco_outlined,
                title: 'Daftar Akun Baru',
                subtitle: 'Kumpulkan poin lingkungan dari setoran sampah pintar SmartBIN di sekeliling kampusmu.',
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                AuthNotice(icon: Icons.error_outline, title: 'Pendaftaran gagal', body: _error!, tone: PillTone.error),
                const SizedBox(height: 16),
              ],
              const FieldLabel('Nomor Induk Mahasiswa (NIM)'),
              TextFormField(
                controller: _nim,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Contoh: 2106728190',
                  prefixIcon: Icon(Icons.badge_outlined),
                  helperText: 'Wajib unik & sesuai kartu identitas kampus aktif',
                ),
                validator: (v) {
                  if (_serverErrors['nim'] != null) return _serverErrors['nim'];
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'NIM wajib diisi';
                  if (!RegExp(r'^\d{8,15}$').hasMatch(s)) return 'NIM berupa 8–15 digit angka';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              const FieldLabel('Nama Lengkap'),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(hintText: 'Misal: Muhammad Alif Ramadhan', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Nama minimal 3 karakter' : null,
              ),
              const SizedBox(height: 18),
              const FieldLabel('Email Kampus (.ac.id)'),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  hintText: 'nama@ui.ac.id',
                  prefixIcon: Icon(Icons.school_outlined),
                  helperText: 'Gunakan domain institusi (.ac.id) resmi Anda',
                ),
                validator: (v) {
                  if (_serverErrors['email'] != null) return _serverErrors['email'];
                  final s = v?.trim() ?? '';
                  if (!RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.ac\.id$').hasMatch(s)) return 'Masukkan email kampus berakhiran .ac.id';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              const FieldLabel('Kata Sandi'),
              TextFormField(
                controller: _pw,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  hintText: 'Min. 8 karakter (huruf & angka)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Tampilkan sandi' : 'Sembunyikan sandi',
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  final s = v ?? '';
                  if (s.length < 8) return 'Minimal 8 karakter';
                  if (!RegExp('[A-Za-z]').hasMatch(s) || !RegExp('[0-9]').hasMatch(s)) return 'Harus berisi huruf dan angka';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border.withValues(alpha: 0.6)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('Kekuatan Sandi:', style: context.text.labelMedium?.copyWith(color: p.textSecondary)),
                        const Spacer(),
                        Text(strengthLabel, style: context.text.labelMedium?.copyWith(color: strengthColor)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 1; i <= 3; i++) ...[
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 6,
                              decoration: BoxDecoration(color: i <= strength ? strengthColor : p.skeleton, borderRadius: BorderRadius.circular(999)),
                            ),
                          ),
                          if (i < 3) const SizedBox(width: 4),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const FieldLabel('Konfirmasi Kata Sandi'),
              TextFormField(
                controller: _pw2,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: 'Ketik ulang kata sandi Anda', prefixIcon: Icon(Icons.verified_user_outlined)),
                validator: (v) => v != _pw.text ? 'Kata sandi tidak sama' : null,
              ),
              const SizedBox(height: 20),
              SectionCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      value: _agree,
                      onChanged: (v) => setState(() {
                        _agree = v ?? false;
                        if (_agree) _showAgreeError = false;
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: p.brand,
                      title: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Saya menyetujui '),
                            TextSpan(
                              text: 'Syarat & Ketentuan',
                              style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(text: ' serta '),
                            TextSpan(
                              text: 'Kebijakan Privasi',
                              style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(text: ' SmartBIN sesuai UU Pelindungan Data Pribadi (UU No. 27/2022).'),
                          ],
                        ),
                        style: context.text.bodySmall?.copyWith(color: p.textSecondary, height: 1.5),
                      ),
                    ),
                    if (_showAgreeError)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 4),
                        child: Text('Anda harus menyetujui kebijakan privasi', style: context.text.bodySmall?.copyWith(color: p.error)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: p.brandDark),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Row(mainAxisSize: MainAxisSize.min, children: [Text('Daftar Sekarang'), SizedBox(width: 8), Icon(Icons.arrow_forward)]),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield, size: 16, color: p.textPrimary),
                  const SizedBox(width: 6),
                  Text('Data dikirim aman lewat koneksi terenkripsi', style: context.text.bodySmall?.copyWith(color: p.textMuted)),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    Text('Sudah memiliki akun mahasiswa?', style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
                    TextButton.icon(
                      onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
                      icon: const Icon(Icons.login),
                      label: const Text('Masuk ke Akun Anda'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
