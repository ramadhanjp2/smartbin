import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/nfc_reader.dart';
import '../../state/providers.dart';

enum _Phase { idle, scanning, linking, success, error }

/// S04 – Tautkan KTM lewat NFC.
class LinkKtmScreen extends ConsumerStatefulWidget {
  const LinkKtmScreen({super.key});

  @override
  ConsumerState<LinkKtmScreen> createState() => _LinkKtmScreenState();
}

class _LinkKtmScreenState extends ConsumerState<LinkKtmScreen> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  _Phase _phase = _Phase.idle;
  NfcAvailability? _nfc;
  String? _error;
  LinkResult? _result;

  @override
  void initState() {
    super.initState();
    ref.read(nfcReaderProvider).availability().then((a) {
      if (mounted) setState(() => _nfc = a);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _phase = _Phase.scanning;
      _error = null;
    });
    try {
      final uid = await ref.read(nfcReaderProvider).readUid();
      if (!mounted) return;
      setState(() => _phase = _Phase.linking);
      final result = await ref.read(authProvider.notifier).linkCard(uid);
      if (!mounted) return;
      setState(() {
        _phase = _Phase.success;
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e is AppException ? e.message : 'Kartu tidak terbaca. Tempelkan KTM lebih lama di bagian belakang ponsel.';
      });
    }
  }

  void _finish() {
    final auth = ref.read(authProvider.notifier);
    if (ref.read(authProvider).needsCardSetup) {
      auth.finishCardSetup();
      context.go('/home');
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final firstRun = ref.watch(authProvider).needsCardSetup;
    final user = ref.watch(currentUserProvider);
    final held = ref.watch(pointsSummaryProvider).value?.heldPoints ?? 0;

    if (_phase == _Phase.success) return _SuccessView(result: _result!, onDone: _finish);

    final nfcOff = _nfc == NfcAvailability.disabled || _nfc == NfcAvailability.notSupported;
    final busy = _phase == _Phase.scanning || _phase == _Phase.linking;

    return Scaffold(
      appBar: SmartbinAppBar(title: 'Tautkan KTM', showBack: !firstRun),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 18, color: p.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Registrasi Identitas Eco', style: context.text.labelLarge?.copyWith(color: p.textMuted)),
              ),
              if (firstRun) const StatusPill(label: 'Langkah 2 dari 2'),
            ],
          ),
          const SizedBox(height: 12),
          Text('Tautkan KTM Mahasiswa', style: context.text.headlineLarge?.copyWith(color: p.textPrimary)),
          const SizedBox(height: 6),
          Text(
            'Tempelkan Kartu Tanda Mahasiswa (KTM RFID 13,56 MHz) ke bagian belakang ponsel Anda untuk verifikasi instan.',
            style: context.text.bodyMedium?.copyWith(color: p.textMuted, height: 1.5),
          ),
          const SizedBox(height: 20),

          // Area pindai
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: p.cardMuted, borderRadius: BorderRadius.circular(28)),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: nfcOff ? p.error : p.success),
                      ),
                      const SizedBox(width: 8),
                      Text(switch ((_nfc, _phase)) {
                        (NfcAvailability.notSupported, _) => 'Ponsel tidak mendukung NFC',
                        (NfcAvailability.disabled, _) => 'NFC Mati',
                        (_, _Phase.scanning) => 'Mendeteksi kartu…',
                        (_, _Phase.linking) => 'Menautkan ke akun…',
                        _ => 'NFC Aktif & Siap Memindai',
                      }, style: context.text.labelLarge?.copyWith(color: p.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 230,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) => Stack(
                      alignment: Alignment.center,
                      children: [
                        for (final offset in [0.0, 0.5])
                          if (busy)
                            Opacity(
                              opacity: (1 - ((_pulse.value + offset) % 1)).clamp(0, 1) * 0.6,
                              child: Container(
                                width: 140 + 140 * ((_pulse.value + offset) % 1),
                                height: 140 + 140 * ((_pulse.value + offset) % 1),
                                decoration: BoxDecoration(shape: BoxShape.circle, color: p.accentSoft),
                              ),
                            ),
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: p.accentSoft.withValues(alpha: 0.35)),
                        ),
                        child!,
                      ],
                    ),
                    child: Transform.rotate(
                      angle: -4 * math.pi / 180,
                      child: _KtmIllustration(name: user?.name ?? '', nim: user?.nim ?? ''),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: p.skeleton.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: p.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Posisikan kartu dekat kamera belakang ponsel',
                          style: context.text.labelMedium?.copyWith(color: p.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_phase == _Phase.error && _error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: p.errorSoft, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: p.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_error!, style: context.text.bodyMedium?.copyWith(color: p.error)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Alasan menautkan
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: p.accentSoft,
                      child: Icon(Icons.lightbulb_outline, color: p.textPrimary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Mengapa harus menautkan KTM?', style: context.text.headlineSmall?.copyWith(color: p.textPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _Reason(n: 1, title: 'Poin Masuk Otomatis', body: 'Setiap setoran di mesin langsung terkonversi ke saldo akun Anda.'),
                if (held > 0)
                  _Reason(
                    n: 2,
                    title: 'Cairkan ${Fmt.points(held)} Poin Tertahan',
                    body: 'Ada poin dari setoran sebelumnya yang menunggu konfirmasi kepemilikan Anda.',
                    highlight: true,
                  ),
                _Reason(
                  n: held > 0 ? 3 : 2,
                  title: 'Tanpa Repot Buka Aplikasi',
                  body: 'Cukup tempelkan KTM ke scanner mesin SmartBIN di koridor kampus.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (nfcOff || _phase == _Phase.error)
            Center(
              child: TextButton.icon(
                onPressed: () => ref.read(nfcReaderProvider).openSettings(),
                icon: const Icon(Icons.build_outlined, size: 18),
                label: const Text('NFC Bermasalah? Buka Pengaturan NFC'),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: busy || _nfc == NfcAvailability.notSupported ? null : _scan,
            icon: busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.contactless),
            label: Text(switch (_phase) {
              _Phase.scanning => 'Tempelkan KTM sekarang…',
              _Phase.linking => 'Menautkan…',
              _Phase.error => 'Coba Pindai Lagi',
              _ => 'Mulai Pindai NFC',
            }),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: busy ? null : _finish, child: Text(firstRun ? 'Lewati Sementara' : 'Nanti Saja')),
          if (firstRun)
            Text(
              'Poin dari setoran tetap disimpan sebagai poin tertahan sampai KTM ditautkan.',
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: p.textMuted),
            ),
        ],
      ),
    );
  }
}

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

class _KtmIllustration extends StatelessWidget {
  const _KtmIllustration({required this.name, required this.nim});
  final String name, nim;

  @override
  Widget build(BuildContext context) {
    const soft = Color(0xFFA5D6A7);
    final t = context.text;
    return Container(
      width: 280,
      height: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined, color: soft, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text('KARTU TANDA\nMAHASISWA', style: t.labelSmall?.copyWith(color: soft, letterSpacing: 1.4)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                child: Text('13,56 MHz', style: t.labelSmall?.copyWith(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 30,
            decoration: BoxDecoration(color: const Color(0xFFF9C74F), borderRadius: BorderRadius.circular(6)),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NIM Mahasiswa', style: t.labelSmall?.copyWith(color: Colors.white70)),
                    Text(nim.isEmpty ? '••••••••••' : nim, style: t.titleMedium?.copyWith(color: Colors.white, letterSpacing: 1.5)),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.labelSmall?.copyWith(color: soft),
                    ),
                  ],
                ),
              ),
              Text('SMARTBIN', style: t.labelSmall?.copyWith(color: Colors.white70)),
            ],
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
                'KTM Berhasil Ditautkan!',
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
