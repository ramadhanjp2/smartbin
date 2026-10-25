import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [sharedPrefsProvider.overrideWithValue(prefs)], child: const SmartbinApp()));
}

class SmartbinApp extends ConsumerWidget {
  const SmartbinApp({super.key, this.fontFamily});

  /// Override font untuk test; null = Plus Jakarta Sans.
  final String? fontFamily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SmartBIN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(fontFamily: fontFamily),
      darkTheme: AppTheme.dark(fontFamily: fontFamily),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // NFR-09: dukung font sistem hingga 130%.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
          child: child!,
        );
      },
    );
  }
}
