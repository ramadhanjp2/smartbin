import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/nfc_reader.dart';
import '../../state/providers.dart';

part 'link_ktp_illustration.dart';
part 'link_ktp_views.dart';

enum _Phase { idle, scanning, linking, success, error }

/// S04 – Tautkan KTP lewat NFC.
class LinkKtpScreen extends ConsumerStatefulWidget {
  const LinkKtpScreen({super.key});

  @override
  ConsumerState<LinkKtpScreen> createState() => _LinkKtpScreenState();
}

class _LinkKtpScreenState extends ConsumerState<LinkKtpScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  _Phase _phase = _Phase.idle;
  NfcAvailability? _nfc;
  String? _availabilityError;
  String? _error;
  LinkResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAvailability();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    try {
      final availability = await ref.read(nfcReaderProvider).availability();
      if (mounted) {
        setState(() {
          _nfc = availability;
          _availabilityError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _availabilityError = error.toString());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(ref.read(nfcReaderProvider).cancel());
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
        _error = switch (e) {
          AppException() => e.message,
          NfcReaderException() => e.message,
          TimeoutException() => e.message ?? 'Kartu tidak terdeteksi. Tempelkan KTP lebih lama di bagian belakang ponsel.',
          _ => 'Kartu tidak terbaca. Pastikan NFC aktif dan coba tempelkan kembali e-KTP.',
        };
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
    final held = ref.watch(pointsSummaryProvider).value?.heldPoints ?? 0;

    if (_phase == _Phase.success) return _SuccessView(result: _result!, onDone: _finish);

    final nfcEnabled = ref.watch(nfcEnabledProvider);
    final nfcOff =
        !nfcEnabled || _nfc == null || _availabilityError != null || _nfc == NfcAvailability.disabled || _nfc == NfcAvailability.notSupported;
    final busy = _phase == _Phase.scanning || _phase == _Phase.linking;

    return Scaffold(
      appBar: SmartbinAppBar(title: 'Tautkan KTP', showBack: !firstRun),
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
          Text('Tautkan KTP', style: context.text.headlineLarge?.copyWith(color: p.textPrimary)),
          const SizedBox(height: 6),
          Text(
            'Tempelkan kartu KTP ke bagian belakang ponsel untuk menghubungkan kartu yang digunakan pada mesin SmartBIN.',
            style: context.text.bodyMedium?.copyWith(color: p.textMuted, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Aplikasi membaca UID NFC e-KTP, bukan data identitas di dalam chip. Dukungan baca UID dapat berbeda menurut kartu dan model ponsel; UID yang terbaca harus sama dengan UID yang dikenali pembaca mesin.',
            style: context.text.bodySmall?.copyWith(color: p.warning, height: 1.45),
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
                        (_, _) when _availabilityError != null => 'NFC Tidak Dapat Diperiksa',
                        (_, _) when _nfc == null => 'Memeriksa NFC…',
                        (_, _) when !nfcEnabled => 'NFC Dinonaktifkan di Profil',
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
                    child: const _KtpIllustration(),
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
          if ((_phase == _Phase.error && _error != null) || _availabilityError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: p.errorSoft, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: p.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_availabilityError ?? _error!, style: context.text.bodyMedium?.copyWith(color: p.error)),
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
                      child: Text('Mengapa harus menautkan KTP?', style: context.text.headlineSmall?.copyWith(color: p.textPrimary)),
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
                  body: 'Cukup tempelkan KTP ke pembaca kartu mesin SmartBIN di lokasi terdekat.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_nfc == NfcAvailability.disabled || _phase == _Phase.error)
            Center(
              child: TextButton.icon(
                onPressed: () => ref.read(nfcReaderProvider).openSettings(),
                icon: const Icon(Icons.build_outlined, size: 18),
                label: const Text('NFC Bermasalah? Buka Pengaturan NFC'),
              ),
            ),
          if (_availabilityError != null)
            Center(
              child: TextButton.icon(onPressed: _checkAvailability, icon: const Icon(Icons.refresh, size: 18), label: const Text('Periksa NFC Lagi')),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: busy || nfcOff ? null : _scan,
            icon: busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.contactless),
            label: Text(switch (_phase) {
              _Phase.scanning => 'Tempelkan KTP sekarang…',
              _Phase.linking => 'Menautkan…',
              _Phase.error => 'Coba Pindai Lagi',
              _ => 'Mulai Pindai NFC',
            }),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: busy ? null : _finish, child: Text(firstRun ? 'Lewati Sementara' : 'Nanti Saja')),
          if (firstRun)
            Text(
              'Poin dari setoran tetap disimpan sebagai poin tertahan sampai KTP ditautkan.',
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: p.textMuted),
            ),
        ],
      ),
    );
  }
}
