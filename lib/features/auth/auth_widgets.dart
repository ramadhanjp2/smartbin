import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

class AuthHero extends StatelessWidget {
  const AuthHero({super.key, required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: [p.cardMuted, p.accentSoft.withValues(alpha: 0.6)]),
      ),
      child: Row(
        children: [
          IconTile(icon: icon, size: 56, background: p.brand, foreground: Colors.white),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.headlineMedium?.copyWith(color: p.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AuthNotice extends StatelessWidget {
  const AuthNotice({super.key, required this.icon, required this.title, required this.body, required this.tone});
  final IconData icon;
  final String title, body;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (bg, fg) = switch (tone) {
      PillTone.error => (p.errorSoft, p.error),
      PillTone.warning => (p.warningSoft, p.warning),
      _ => (p.cardMuted, p.textPrimary),
    };
    return Semantics(
      liveRegion: tone == PillTone.error,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(body, style: context.text.bodySmall?.copyWith(color: fg)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: context.text.labelLarge?.copyWith(color: p.textSecondary, fontSize: 15)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
