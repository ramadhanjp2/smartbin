import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/card/link_ktp_screen.dart';
import '../../features/history/deposit_detail_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/machines/machines_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/rates_guide_screen.dart';
import '../../state/providers.dart';
import 'main_shell.dart';

const _guestRoutes = {'/onboarding', '/login', '/register'};

final routerProvider = Provider<GoRouter>((ref) {
  // Menjembatani perubahan state Riverpod ke go_router agar redirect dievaluasi ulang.
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.listen(onboardingSeenProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final auth = ref.read(authProvider);
      final user = auth.user;

      if (!ref.read(onboardingSeenProvider)) return loc == '/onboarding' ? null : '/onboarding';
      if (user == null) return (_guestRoutes.contains(loc) && loc != '/onboarding') ? null : '/login';
      if (auth.needsCardSetup) return loc == '/link-ktp' ? null : '/link-ktp';
      if (_guestRoutes.contains(loc)) return user.role == UserRole.admin ? '/admin' : '/home';
      if (loc == '/admin' && user.role != UserRole.admin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/login',
        builder: (_, s) => LoginScreen(message: s.uri.queryParameters['msg']),
      ),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/link-ktp', builder: (_, _) => const LinkKtpScreen()),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(
        path: '/deposit/:id',
        builder: (_, s) => DepositDetailScreen(transactionId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/rates', builder: (_, _) => const RatesGuideScreen()),
      GoRoute(path: '/admin', builder: (_, _) => const AdminDashboardScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/history', builder: (_, _) => const HistoryScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/machines', builder: (_, _) => const MachinesScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),
    ],
  );
});
