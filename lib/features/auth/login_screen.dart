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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final form = ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const AuthHero(
                icon: Icons.recycling,
                title: 'Selamat Datang!',
                subtitle: 'Setor sampah, kumpulkan poin, dan jaga bumi bersama SmartBIN.',
              ),
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
                        FieldLabel(_admin ? 'Email Admin' : 'NIK KTP atau Email'),
                        TextFormField(
                          controller: _id,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          decoration: InputDecoration(
                            hintText: _admin ? 'admin@smartbin.id' : 'Masukkan NIK 16 digit atau email',
                            prefixIcon: const Icon(Icons.person_outline),
                            fillColor: p.cardMuted,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: FieldLabel('Kata Sandi')),
                            TextButton(
                              onPressed: () => showSnack(context, 'Reset kata sandi lewat email tersedia di Rilis 2. Hubungi dukungan SmartBIN.'),
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
          );

          if (constraints.maxWidth >= 900) {
            return Row(
              children: [
                Expanded(child: _SmartBinWelcomePanel()),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: SafeArea(top: false, child: form),
                    ),
                  ),
                ),
              ],
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [p.background, const Color(0xFFE4F4EB), const Color(0xFFF7F5E9)],
                  ),
                ),
              ),
              Positioned(
                top: -90,
                right: -120,
                width: 310,
                height: 310,
                child: Opacity(opacity: 0.09, child: CustomPaint(painter: _SmartBinIllustrationPainter())),
              ),
              SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: form),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SmartBinWelcomePanel extends StatelessWidget {
  const _SmartBinWelcomePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF073F35), Color(0xFF0B5B49), Color(0xFF14805D)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -130,
            left: -100,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 42),
              ),
            ),
          ),
          Positioned(
            right: -100,
            bottom: 60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFB4E57A).withValues(alpha: 0.08)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 34, 36, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.recycling, color: Color(0xFFD8F6B2), size: 26),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'SmartBIN',
                      style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                    ),
                    const Spacer(),
                    _PanelTag(label: 'SMART LIVING'),
                  ],
                ),
                const SizedBox(height: 58),
                const _PanelTag(label: 'TEKNOLOGI UNTUK BUMI'),
                const SizedBox(height: 18),
                Text(
                  'Sampah jadi\nlebih berarti.',
                  style: context.text.displayLarge?.copyWith(color: Colors.white, fontSize: 42, height: 1.12, letterSpacing: -1.1),
                ),
                const SizedBox(height: 14),
                Text(
                  'Setor sampah, pantau dampak, dan kumpulkan poin dalam ekosistem lingkungan yang lebih hijau.',
                  style: context.text.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.78), height: 1.65),
                ),
                const SizedBox(height: 20),
                const Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _FeaturePill(icon: Icons.sensors, label: 'Sensor IoT'),
                    _FeaturePill(icon: Icons.stars_rounded, label: 'Poin setoran'),
                  ],
                ),
                const Spacer(),
                const Expanded(
                  child: Center(
                    child: CustomPaint(painter: _SmartBinIllustrationPainter(), child: SizedBox.expand()),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.eco_outlined, color: const Color(0xFFD8F6B2), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Langkah kecil, dampak besar untuk bumi.',
                      style: context.text.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.72)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelTag extends StatelessWidget {
  const _PanelTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Color(0xFFD8F6B2), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.15),
    ),
  );
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFFD8F6B2)),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _SmartBinIllustrationPainter extends CustomPainter {
  const _SmartBinIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / 320).clamp(0.35, 1.4);
    canvas.save();
    canvas.translate((size.width - 320 * scale) / 2, (size.height - 380 * scale) / 2);
    canvas.scale(scale);

    final glow = Paint()..color = const Color(0xFFB4E57A).withValues(alpha: 0.12);
    canvas.drawCircle(const Offset(160, 194), 158, glow);
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawCircle(const Offset(160, 194), 136, ringPaint);
    canvas.drawCircle(const Offset(160, 194), 150, ringPaint..color = Colors.white.withValues(alpha: 0.07));

    final shadow = Paint()..color = const Color(0xFF002D25).withValues(alpha: 0.3);
    canvas.drawOval(const Rect.fromLTWH(54, 331, 214, 27), shadow);

    final body = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFECF7D8), Color(0xFFBFE4A2)],
      ).createShader(const Rect.fromLTWH(62, 120, 196, 220));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(62, 120, 196, 218), const Radius.circular(28)), body);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(62, 120, 196, 218), const Radius.circular(28)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final lid = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFFDDF4B8), Color(0xFF9DCE77)]).createShader(const Rect.fromLTWH(48, 94, 224, 36));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(48, 96, 224, 34), const Radius.circular(14)), lid);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(127, 84, 66, 12), const Radius.circular(6)),
      Paint()..color = const Color(0xFFB9E696),
    );

    final screen = Paint()..color = const Color(0xFF174E43);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(91, 145, 138, 72), const Radius.circular(16)), screen);
    canvas.drawCircle(const Offset(111, 168), 5, Paint()..color = const Color(0xFF8EE6A0));
    _drawText(canvas, 'SMARTBIN', const Offset(124, 157), const Color(0xFFEAF7DC), 10, FontWeight.w800);
    _drawText(canvas, 'READY TO RECYCLE', const Offset(106, 181), const Color(0xFFB8D7C2), 8, FontWeight.w600);

    final recyclePaint = Paint()
      ..color = const Color(0xFF347F5E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: const Offset(160, 269), radius: 25), -2.35, 1.65, false, recyclePaint);
    canvas.drawArc(Rect.fromCircle(center: const Offset(160, 269), radius: 25), -0.25, 1.65, false, recyclePaint);
    canvas.drawArc(Rect.fromCircle(center: const Offset(160, 269), radius: 25), 1.85, 1.65, false, recyclePaint);
    canvas.drawCircle(const Offset(160, 269), 5, Paint()..color = const Color(0xFF347F5E));

    final sensor = Paint()
      ..color = const Color(0xFF68C58A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawArc(Rect.fromCircle(center: const Offset(267, 155), radius: 18), -0.85, 1.7, false, sensor);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(267, 155), radius: 29),
      -0.85,
      1.7,
      false,
      sensor..color = const Color(0xFF68C58A).withValues(alpha: 0.6),
    );
    canvas.drawCircle(const Offset(267, 155), 3.5, Paint()..color = const Color(0xFFB4E57A));

    final wheel = Paint()..color = const Color(0xFF174E43);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(92, 329, 32, 17), const Radius.circular(8)), wheel);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(196, 329, 32, 17), const Radius.circular(8)), wheel);

    _drawLeaf(canvas, const Offset(46, 269), -0.5);
    _drawLeaf(canvas, const Offset(277, 287), 0.65);
    _drawBottle(canvas, const Offset(39, 314), -0.18);
    _drawBottle(canvas, const Offset(276, 318), 0.2);
    canvas.restore();
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color, double size, FontWeight weight) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight, letterSpacing: 0.7),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _drawLeaf(Canvas canvas, Offset position, double rotation) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);
    final leaf = Paint()..color = const Color(0xFFA8DE7E);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(10, -22, 31, -15)
      ..quadraticBezierTo(27, 8, 0, 0);
    canvas.drawPath(path, leaf);
    canvas.drawLine(
      Offset.zero,
      const Offset(25, -12),
      Paint()
        ..color = const Color(0xFF47895D)
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  void _drawBottle(Canvas canvas, Offset position, double rotation) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);
    final bottle = Paint()
      ..color = const Color(0xFFB9E8D0).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final path = Path()
      ..moveTo(6, 0)
      ..lineTo(14, 0)
      ..lineTo(14, 7)
      ..lineTo(18, 12)
      ..lineTo(18, 42)
      ..quadraticBezierTo(10, 48, 2, 42)
      ..lineTo(2, 12)
      ..lineTo(6, 7)
      ..close();
    canvas.drawPath(path, bottle);
    canvas.drawLine(const Offset(4, 25), const Offset(16, 25), bottle);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
          seg('Publik', Icons.person_outline, !admin, () => onChanged(false)),
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
              useMockRepository
                  ? admin
                        ? 'Akun mock: admin@smartbin.id / admin1234'
                        : 'Akun mock: NIK 1234567890123456 / smartbin123'
                  : 'Mode API: gunakan akun terdaftar. Admin harus memiliki akses Admin / Teknisi.',
              style: context.text.bodySmall?.copyWith(color: p.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
