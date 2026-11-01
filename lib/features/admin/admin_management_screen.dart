import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

part 'admin_management_summary.dart';
part 'admin_management_users.dart';
part 'admin_management_machines.dart';
part 'admin_management_history.dart';

class AdminManagementScreen extends ConsumerStatefulWidget {
  const AdminManagementScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends ConsumerState<AdminManagementScreen> {
  late int _tab;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final machines = ref.watch(machinesProvider);
    final users = ref.watch(adminUsersProvider);
    return Scaffold(
      appBar: const SmartbinAppBar(title: 'Manajemen Admin', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SizedBox(height: 4),
          switch (_tab) {
            0 => _Summary(machines: machines.value ?? const []),
            1 => switch (users) {
              AsyncValue(:final value?) => _Users(users: value, loading: false, search: _search),
              AsyncValue(:final error?) => _Users(users: const [], loading: false, error: error, search: _search),
              _ => _Users(users: const [], loading: true, search: _search),
            },
            2 => _MachineManagement(machines: machines.value ?? const []),
            _ => switch (ref.watch(adminHistoryProvider)) {
              AsyncValue(:final value?) => _HistoryAll(
                history: value.items,
                hasMore: value.hasMore,
                loadingMore: value.loadingMore,
                loadMoreError: value.loadMoreError,
                onLoadMore: () => ref.read(adminHistoryProvider.notifier).loadMore(),
                loading: false,
                search: _search,
                onRefresh: () => ref.invalidate(adminHistoryProvider),
              ),
              AsyncValue(:final error?) => _HistoryAll(
                history: const [],
                loading: false,
                error: error,
                search: _search,
                onRefresh: () => ref.invalidate(adminHistoryProvider),
              ),
              _ => _HistoryAll(history: const [], loading: true, search: _search, onRefresh: () => ref.invalidate(adminHistoryProvider)),
            },
          },
        ],
      ),
    );
  }
}
