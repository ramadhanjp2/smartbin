import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../state/providers.dart';

/// Bottom navigation pengguna: Beranda, Riwayat, Scan KTP, Notifikasi, Profil.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(currentUserProvider)?.role == UserRole.admin;
    if (isAdmin) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt), label: 'Pengguna'),
            NavigationDestination(
              icon: Icon(Icons.precision_manufacturing_outlined),
              selectedIcon: Icon(Icons.precision_manufacturing),
              label: 'Mesin',
            ),
            NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: switch (shell.currentIndex) {
          0 => 0,
          1 => 1,
          2 => 3,
          3 => 4,
          _ => 0,
        },
        onDestinationSelected: (index) {
          if (index == 2) {
            context.push('/link-ktp');
            return;
          }
          final branch = index > 2 ? index - 1 : index;
          shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Riwayat'),
          NavigationDestination(icon: _RaisedScanIcon(), selectedIcon: _RaisedScanIcon(selected: true), label: 'Scan KTP'),
          NavigationDestination(icon: Icon(Icons.notifications_none_outlined), selectedIcon: Icon(Icons.notifications), label: 'Notifikasi'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

class _RaisedScanIcon extends StatelessWidget {
  const _RaisedScanIcon({this.selected = false});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -10),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected ? const [Color(0xFF9BE7A9), Color(0xFF4D9460)] : const [Color(0xFFF2FFF5), Color(0xFFDCEEE0)],
          ),
          border: Border.all(color: selected ? const Color(0xFFD6FFE0) : Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 7)),
            BoxShadow(color: Color(0x66FFFFFF), blurRadius: 4, offset: Offset(-2, -2)),
          ],
        ),
        child: Icon(Icons.qr_code_2_rounded, size: 29, color: selected ? const Color(0xFF123F2A) : const Color(0xFF246B43)),
      ),
    );
  }
}
