part of 'admin_management_screen.dart';

class _HistoryAll extends StatefulWidget {
  const _HistoryAll({
    required this.history,
    required this.search,
    required this.loading,
    required this.onRefresh,
    this.error,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreError,
    this.onLoadMore,
  });
  final List<AdminHistoryRecord> history;
  final bool hasMore;
  final bool loadingMore;
  final Object? loadMoreError;
  final VoidCallback? onLoadMore;
  final TextEditingController search;
  final bool loading;
  final VoidCallback onRefresh;
  final Object? error;
  @override
  State<_HistoryAll> createState() => _HistoryAllState();
}

class _HistoryAllState extends State<_HistoryAll> {
  @override
  Widget build(BuildContext context) {
    final query = widget.search.text.toLowerCase();
    final filtered = widget.history.where((h) => '${h.userName} ${h.userId} ${h.machine} ${h.type}'.toLowerCase().contains(query)).toList();
    if (widget.loading) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
      );
    }
    if (widget.error != null) {
      return ErrorView(error: widget.error!, onRetry: widget.onRefresh);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(onPressed: widget.onRefresh, icon: const Icon(Icons.refresh), label: const Text('Muat ulang riwayat')),
        ),
        TextField(
          controller: widget.search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari transaksi, pengguna, mesin, atau jenis sampah'),
        ),
        if (widget.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Pencarian dan ekspor CSV mencakup ${widget.history.length} baris yang sudah dimuat.',
              style: context.text.labelSmall?.copyWith(color: context.palette.textMuted),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _exportCsv(context, filtered),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Export CSV'),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Belum ada riwayat setoran yang cocok.')),
          ),
        for (final item in filtered)
          SectionCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: context.palette.accentSoft,
                  child: Icon(
                    item.type == 'Organik'
                        ? Icons.compost
                        : item.type == 'Residu'
                        ? Icons.delete_outline
                        : Icons.recycling,
                    color: context.palette.brand,
                  ),
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
                              item.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _InfoChip(label: item.type, color: context.palette.brand),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.machine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: context.palette.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _InfoChip(label: '${item.weightKg} kg', color: context.palette.textSecondary),
                          _InfoChip(label: '${item.points} poin', color: Colors.green),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(Fmt.dateTime(item.time), style: context.text.labelSmall?.copyWith(color: context.palette.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (widget.loadMoreError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              errorText(widget.loadMoreError!),
              textAlign: TextAlign.center,
              style: context.text.labelMedium?.copyWith(color: context.palette.error),
            ),
          ),
        if (widget.hasMore)
          TextButton.icon(
            onPressed: widget.loadingMore ? null : widget.onLoadMore,
            icon: widget.loadingMore
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.expand_more),
            label: Text(widget.loadMoreError != null ? 'Coba Lagi' : 'Muat Lebih Banyak'),
          ),
      ],
    );
  }

  Future<void> _exportCsv(BuildContext context, List<AdminHistoryRecord> rows) async {
    String csvValue(Object value) => '"${value.toString().replaceAll('"', '""')}"';
    const header = 'Nama Pengguna,Mesin,Jenis,Berat kg,Poin,Waktu';
    final data = rows.map((h) => [h.userName, h.machine, h.type, h.weightKg, h.points, Fmt.dateTime(h.time)].map(csvValue).join(',')).join('\n');
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/smartbin_history_${DateFormat('yyyyMMdd_HHmmss').format(Fmt.nowWib())}.csv');
      await file.writeAsString('$header\n$data', flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          text: 'Data history SmartBIN',
        ),
      );
      if (context.mounted) showSnack(context, 'CSV siap diekspor (${rows.length} baris)');
    } catch (e) {
      if (context.mounted) showSnack(context, 'CSV gagal diekspor: $e');
    }
  }
}
