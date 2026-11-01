part of 'link_ktp_screen.dart';

class _Reason extends StatelessWidget {
  const _Reason({required this.n, required this.title, required this.body, this.highlight = false});
  final int n;
  final String title, body;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: highlight ? p.accentSoft.withValues(alpha: 0.6) : p.cardMuted, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: p.brandDark,
            child: Text('$n', style: context.text.labelMedium?.copyWith(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(title, style: context.text.titleMedium?.copyWith(color: p.textPrimary)),
                    if (highlight) const StatusPill(label: 'Klaim', tone: PillTone.brand),
                  ],
                ),
                const SizedBox(height: 2),
                Text(body, style: context.text.bodySmall?.copyWith(color: p.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.result, required this.onDone});
  final LinkResult result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(color: p.accentSoft, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, size: 72, color: p.textPrimary),
              ),
              const SizedBox(height: 24),
              Text(
                'KTP Berhasil Ditautkan!',
                textAlign: TextAlign.center,
                style: context.text.headlineLarge?.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Setiap setoran di mesin SmartBIN kini langsung masuk ke saldo Anda.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: p.textMuted),
              ),
              if (result.creditedPoints > 0) ...[
                const SizedBox(height: 24),
                SectionCard(
                  color: p.cardMuted,
                  child: Row(
                    children: [
                      IconTile(icon: Icons.savings_outlined, background: p.accentSoft),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          '+${Fmt.points(result.creditedPoints)} poin dari ${result.creditedDeposits} setoran dimasukkan ke saldo',
                          style: context.text.titleMedium?.copyWith(color: p.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              FilledButton(onPressed: onDone, child: const Text('Lanjut ke Beranda')),
            ],
          ),
        ),
      ),
    );
  }
}
