part of 'login_screen.dart';

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
                  ? 'Akun mock: NIK 1234567890123456 / smartbin123'
                  : 'Mode API: gunakan akun terdaftar. Login admin dan publik menggunakan form yang sama.',
              style: context.text.bodySmall?.copyWith(color: p.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
