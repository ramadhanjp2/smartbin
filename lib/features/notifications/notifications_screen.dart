import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// S10 – Daftar notifikasi.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _depositsOnly = false;

  Future<void> _open(AppNotification n) async {
    if (!n.read) {
      await ref.read(repositoryProvider).markNotificationRead(n.id);
      ref.invalidate(notificationsProvider);
    }
    if (!mounted) return;
    if (n.depositId != null) {
      context.push('/deposit/${n.depositId}');
    } else if (n.kind == NotificationKind.card || n.kind == NotificationKind.sync) {
      context.go('/profile');
    }
  }

  Future<void> _markAll() async {
    await ref.read(repositoryProvider).markAllNotificationsRead();
    ref.invalidate(notificationsProvider);
    if (mounted) showSnack(context, 'Semua notifikasi ditandai dibaca');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final notifs = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);
    final all = notifs.value ?? const <AppNotification>[];
    final depositCount = all.where((n) => n.kind == NotificationKind.deposit || n.kind == NotificationKind.sync).length;

    return Scaffold(
      appBar: const SmartbinAppBar(title: 'Notifikasi', showBack: true),
      body: RefreshIndicator(
        color: p.brand,
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          try {
            await ref.read(notificationsProvider.future);
          } catch (_) {}
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Notifikasi', style: context.text.headlineLarge?.copyWith(color: p.textPrimary)),
                      if (unread > 0) StatusPill(label: '$unread Belum Dibaca', tone: PillTone.brand),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: unread == 0 ? null : _markAll,
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Tandai Semua'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text('Semua (${all.length})'), icon: const Icon(Icons.inbox_outlined)),
                ButtonSegment(value: true, label: Text('Setoran & Poin ($depositCount)'), icon: const Icon(Icons.recycling)),
              ],
              selected: {_depositsOnly},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _depositsOnly = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: p.brand,
                selectedForegroundColor: Colors.white,
                foregroundColor: p.textSecondary,
                side: BorderSide(color: p.border),
              ),
            ),
            const SizedBox(height: 16),
            switch (notifs) {
              AsyncValue(:final value?) => () {
                final list = _depositsOnly
                    ? value.where((n) => n.kind == NotificationKind.deposit || n.kind == NotificationKind.sync).toList()
                    : value;
                if (list.isEmpty) {
                  return const EmptyView(
                    icon: Icons.notifications_none,
                    title: 'Belum ada notifikasi',
                    message: 'Notifikasi setoran, KTM, dan poin akan muncul di sini.',
                  );
                }
                return Column(
                  children: [
                    for (final n in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _NotificationCard(n: n, onTap: () => _open(n)),
                      ),
                  ],
                );
              }(),
              AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(notificationsProvider)),
              _ => const SkeletonList(count: 4),
            },
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) => SectionCard(
                color: p.cardMuted,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: CircleAvatar(
                    backgroundColor: p.card,
                    child: Icon(Icons.tune, color: p.textPrimary),
                  ),
                  title: Text('Preferensi Notifikasi Push', style: context.text.labelLarge?.copyWith(color: p.textPrimary)),
                  subtitle: Text('Peringatan setoran & KTM', style: context.text.bodySmall?.copyWith(color: p.textMuted)),
                  value: ref.watch(notificationSoundProvider),
                  onChanged: (v) => ref.read(notificationSoundProvider.notifier).set(v),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.n, required this.onTap});
  final AppNotification n;
  final VoidCallback onTap;

  IconData get _icon => switch (n.kind) {
    NotificationKind.deposit => Icons.delete_sweep_outlined,
    NotificationKind.card => Icons.contactless_outlined,
    NotificationKind.sync => Icons.cloud_sync_outlined,
    NotificationKind.achievement => Icons.emoji_events_outlined,
    NotificationKind.machine => Icons.sensors,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '${n.read ? '' : 'Belum dibaca. '}${n.title}',
      button: true,
      child: SectionCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        color: n.read ? p.card : Color.alphaBlend(p.accentSoft.withValues(alpha: 0.18), p.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(
                  icon: _icon,
                  size: 44,
                  background: n.kind == NotificationKind.sync ? p.warningSoft : p.accentSoft,
                  foreground: n.kind == NotificationKind.sync ? p.warning : p.textPrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${Fmt.relativeShort(n.createdAt, DateTime.now())} · SmartBIN',
                              style: context.text.labelMedium?.copyWith(color: p.textMuted),
                            ),
                          ),
                          if (n.points != null)
                            Text('${Fmt.signedPoints(n.points!)} Pts', style: context.text.labelMedium?.copyWith(color: p.success)),
                          if (!n.read) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(color: p.success, shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                      if (n.tag != null) ...[
                        const SizedBox(height: 4),
                        StatusPill(label: n.tag!, tone: n.kind == NotificationKind.sync ? PillTone.warning : PillTone.success),
                      ],
                      const SizedBox(height: 4),
                      Text(n.title, style: context.text.titleMedium?.copyWith(color: p.textPrimary)),
                      const SizedBox(height: 4),
                      Text(n.body, style: context.text.bodySmall?.copyWith(color: p.textSecondary, height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
            if (n.depositId != null && !n.read) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Lihat Detail Transaksi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
