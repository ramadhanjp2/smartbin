part of 'profile_screen.dart';

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
