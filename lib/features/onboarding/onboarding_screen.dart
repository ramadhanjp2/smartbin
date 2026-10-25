import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../state/providers.dart';

/// S01 – Onboarding 3 slide, tampil sekali saat aplikasi pertama dibuka.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;

  static const _slides = [
    (
      Icons.recycling,
      'Apa itu SmartBIN?',
      'Tempat sampah pintar di kampus yang memilah sampah organik dan anorganik, lalu memberi poin dari setiap setoranmu.',
    ),
    (
      Icons.contactless,
      'Cara Menyetor',
      'Tempelkan KTM ke pembaca RFID di mesin, masukkan sampah ke lubang yang sesuai, dan tunggu penimbangan otomatis.',
    ),
    (
      Icons.calculate_outlined,
      'Cara Poin Dihitung',
      'Mesin menghitung poin dari berat sampah × nilai poin per kg. Poin langsung tercatat di aplikasi ini.',
    ),
  ];

  void _done() => ref.read(onboardingSeenProvider.notifier).complete();

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final last = _index == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(onPressed: _done, child: const Text('Lewati')),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final (icon, title, body) = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: p.accentSoft.withValues(alpha: 0.5)),
                          child: Center(
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(color: p.brand, borderRadius: BorderRadius.circular(40)),
                              child: Icon(icon, size: 72, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: context.text.headlineLarge?.copyWith(color: p.textPrimary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: context.text.bodyLarge?.copyWith(color: p.textMuted),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(color: i == _index ? p.brand : p.skeleton, borderRadius: BorderRadius.circular(999)),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: FilledButton(
                onPressed: last ? _done : () => _page.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                child: Text(last ? 'Mulai' : 'Lanjut'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
