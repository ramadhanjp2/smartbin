part of 'link_ktp_screen.dart';

class _KtpIllustration extends StatefulWidget {
  const _KtpIllustration();

  @override
  State<_KtpIllustration> createState() => _KtpIllustrationState();
}

class _KtpIllustrationState extends State<_KtpIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, child) {
        final value = _motion.value;
        final angle = -0.055 + (value * 0.11);
        return Transform.translate(
          offset: Offset(0, -3 + (value * 6)),
          child: Transform.rotate(angle: angle, child: child),
        );
      },
      child: Container(
        width: 280,
        height: 170,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDAF2FA), Color(0xFFA9D7E8), Color(0xFF81BDD3)],
          ),
          border: Border.all(color: const Color(0xFF6CAAC1)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 10))],
        ),
        child: CustomPaint(
          painter: _KtpPatternPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'PROVINSI JAWA BARAT\nREPUBLIK INDONESIA',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, height: 1.05, color: Color(0xFF174E63), fontWeight: FontWeight.w900, letterSpacing: 0.15),
                  ),
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _KtpField(label: 'NIK', value: '••••• •••• •••••'),
                            _KtpField(label: 'Nama', value: 'PENGGUNA ••••••'),
                            _KtpField(label: 'Tempat/Tgl Lahir', value: '••••••, --/--/----'),
                            _KtpField(label: 'Jenis Kelamin', value: '••••••••'),
                            _KtpField(label: 'Alamat', value: 'JL. •••••••••••••'),
                            _KtpField(label: 'Agama', value: '•••••'),
                            _KtpField(label: 'Status Perkawinan', value: '••••••••'),
                            _KtpField(label: 'Pekerjaan', value: '•••••••••••'),
                            _KtpField(label: 'Kewarganegaraan', value: 'WNI'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Column(
                        children: const [
                          _MaskedPortrait(),
                          SizedBox(height: 3),
                          Text(
                            '•••••••••••',
                            style: TextStyle(fontSize: 6.2, color: Color(0xFF174E63), fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaskedPortrait extends StatelessWidget {
  const _MaskedPortrait();

  @override
  Widget build(BuildContext context) => Container(
    width: 58,
    height: 70,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFFC9E7EE),
      border: Border.all(color: const Color(0xFF397889)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        const Icon(Icons.person, size: 53, color: Color(0xFF397889)),
        Container(color: const Color(0xFF397889).withValues(alpha: 0.16)),
        Container(
          width: 48,
          height: 11,
          transform: Matrix4.translationValues(0, -2, 0),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(2)),
          alignment: Alignment.center,
          child: const Text(
            'IDENTITAS SAMARAN',
            style: TextStyle(fontSize: 4.7, color: Color(0xFF174E63), fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

class _KtpPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 4; i++) {
      final path = Path()..moveTo(-20, 48 + (i * 28));
      path.cubicTo(70, 8 + (i * 28), 170, 112 + (i * 14), size.width + 20, 35 + (i * 30));
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _KtpField extends StatelessWidget {
  const _KtpField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      '$label: $value',
      style: const TextStyle(fontSize: 7.5, height: 1.15, color: Color(0xFF174E63), fontWeight: FontWeight.w800),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}
