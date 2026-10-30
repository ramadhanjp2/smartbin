import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom navigation pengguna: Beranda, Riwayat, Scan KTP, Notifikasi, Profil.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: switch (shell.currentIndex) { 0 => 0, 1 => 1, 2 => 3, 3 => 4, _ => 0 },
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
          NavigationDestination(icon: Icon(Icons.contactless_outlined), selectedIcon: Icon(Icons.contactless), label: 'Scan KTP'),
          NavigationDestination(icon: Icon(Icons.notifications_none_outlined), selectedIcon: Icon(Icons.notifications), label: 'Notifikasi'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
