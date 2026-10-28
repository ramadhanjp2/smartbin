import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';

/// App bar bergaya Stitch: logo, "SmartBIN" + nama layar, lonceng notifikasi, avatar.
class SmartbinAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const SmartbinAppBar({super.key, required this.title, this.showBack = false, this.actions});

  final String title;
  final bool showBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final unread = ref.watch(unreadCountProvider);
    final user = ref.watch(currentUserProvider);
    return AppBar(
      toolbarHeight: 68,
      backgroundColor: p.card,
      automaticallyImplyLeading: false,
      titleSpacing: showBack ? 0 : 20,
      leading: showBack
          ? IconButton(
              tooltip: 'Kembali',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
            )
          : null,
      title: Row(
        children: [
          if (!showBack) ...[const BrandMark(size: 36), const SizedBox(width: 12)],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SmartBIN',
                  style: context.text.headlineSmall?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w800, height: 1.1),
                ),
                Text(
                  title,
                  style: context.text.labelMedium?.copyWith(color: p.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions:
          actions ??
          [
            IconButton(
              tooltip: unread > 0 ? 'Notifikasi, $unread belum dibaca' : 'Notifikasi',
              onPressed: () => context.push('/notifications'),
              icon: Badge(
                isLabelVisible: unread > 0,
                backgroundColor: p.error,
                smallSize: 9,
                child: Icon(Icons.notifications_outlined, color: p.textPrimary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16, left: 4),
              child: Semantics(
                button: true,
                label: 'Profil',
                child: GestureDetector(
                  onTap: () => context.go('/profile'),
                  child: UserAvatar(user: user, size: 40),
                ),
              ),
            ),
          ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(color: p.border.withValues(alpha: 0.5)),
      ),
    );
  }
}

/// Header sederhana untuk layar auth/admin: "SMARTBIN" kecil + judul besar.
class EyebrowAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EyebrowAppBar({super.key, required this.eyebrow, required this.title, this.onBack, this.trailing});

  final String eyebrow;
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppBar(
      toolbarHeight: 76,
      automaticallyImplyLeading: false,
      leading: onBack == null ? null : IconButton(tooltip: 'Kembali', icon: const Icon(Icons.arrow_back), onPressed: onBack),
      titleSpacing: onBack == null ? 20 : 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: context.text.labelMedium?.copyWith(color: p.success, letterSpacing: 1.2, fontWeight: FontWeight.w700),
          ),
          Text(title, style: context.text.headlineMedium?.copyWith(color: p.textSecondary)),
        ],
      ),
      actions: [if (trailing != null) Padding(padding: const EdgeInsets.only(right: 16), child: trailing)],
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Image.asset('assets/images/smartbin-icon.png', width: size, height: size, fit: BoxFit.cover),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.size = 40});
  final AppUser? user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.brand,
        border: Border.all(color: p.accentSoft, width: size > 60 ? 4 : 2),
      ),
      child: user == null
          ? Icon(Icons.person_outline, color: Colors.white, size: size * 0.5)
          : Text(
              user!.initials,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.36),
            ),
    );
  }
}

/// Kartu putih membulat dengan border hijau tipis (surface-card di Stitch).
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.color, this.onTap, this.radius = 24});

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: color ?? p.card,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: p.border.withValues(alpha: 0.6)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.size = 48, this.background, this.foreground, this.radius});

  final IconData icon;
  final double size;
  final Color? background;
  final Color? foreground;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background ?? p.cardMuted, borderRadius: BorderRadius.circular(radius ?? size * 0.3)),
      child: Icon(icon, color: foreground ?? p.textPrimary, size: size * 0.5),
    );
  }
}

enum PillTone { success, warning, error, neutral, brand }

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = PillTone.success, this.icon, this.dot = false});

  final String label;
  final PillTone tone;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (bg, fg) = switch (tone) {
      PillTone.success => (p.accentSoft, p.textPrimary),
      PillTone.warning => (p.warningSoft, p.warning),
      PillTone.error => (p.errorSoft, p.error),
      PillTone.neutral => (p.cardMuted, p.textMuted),
      PillTone.brand => (p.brand, Colors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(
            label,
            style: context.text.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.icon, this.trailing});
  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, color: p.textPrimary, size: 22), const SizedBox(width: 8)],
          Expanded(
            child: Text(
              title,
              style: context.text.headlineSmall?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w700),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Skeleton berdenyut (PRD: loading memakai skeleton, bukan spinner layar penuh).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 999});
  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: p.skeleton, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 88});
  final double height;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: height - 32,
        child: const Row(
          children: [
            Skeleton(width: 52, height: 52, radius: 16),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Skeleton(width: 140), SizedBox(height: 8), Skeleton(width: 90, height: 12)],
              ),
            ),
            Skeleton(width: 56, height: 22),
          ],
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Memuat data',
    child: Column(
      children: [for (var i = 0; i < count; i++) const Padding(padding: EdgeInsets.only(bottom: 12), child: SkeletonCard())],
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final msg = error is AppException ? error.toString() : 'Gagal memuat data. Periksa koneksi internet Anda.';
    return SectionCard(
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, color: p.warning, size: 40),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center, style: context.text.bodyMedium),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          IconTile(icon: icon, size: 64, background: p.accentSoft),
          const SizedBox(height: 16),
          Text(
            title,
            style: context.text.titleMedium?.copyWith(color: p.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: context.text.bodyMedium?.copyWith(color: p.textMuted),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Bilah progres kapasitas tong.
class FillBar extends StatelessWidget {
  const FillBar({super.key, required this.percent, this.color});
  final int percent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: percent / 100,
        minHeight: 10,
        backgroundColor: p.skeleton,
        valueColor: AlwaysStoppedAnimation(color ?? fillColor(context, percent)),
      ),
    );
  }

  static Color fillColor(BuildContext context, int percent) {
    final p = context.palette;
    if (percent >= 90) return p.error;
    if (percent >= 75) return p.warning;
    return p.success;
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String errorText(Object e) => e is AppException ? e.message : 'Terjadi kesalahan. Periksa koneksi dan coba lagi.';
