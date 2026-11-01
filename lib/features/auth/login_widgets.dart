part of 'login_screen.dart';

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
