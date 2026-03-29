import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kanban_board/core/theme.dart';
import 'package:kanban_board/features/board/data/hive_board_repository.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:kanban_board/router/app_router.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await Hive.initFlutter();

  final boardsBox = await Hive.openBox<Map<dynamic, dynamic>>(
    HiveBoardRepository.boxName,
  );
  final columnsBox = await Hive.openBox<Map<dynamic, dynamic>>(
    HiveBoardRepository.columnBoxName,
  );
  final cardsBox = await Hive.openBox<Map<dynamic, dynamic>>(
    HiveBoardRepository.cardBoxName,
  );

  await initializeDateFormatting();

  FlutterNativeSplash.remove();

  runApp(
    ProviderScope(
      overrides: [
        boardRepositoryProvider.overrideWith((ref) {
          final repo = HiveBoardRepository(
            boardsBox,
            columnsBox,
            cardsBox,
          );
          ref.onDispose(repo.dispose);
          return repo;
        }),
      ],
      child: const KanbanApp(),
    ),
  );
}

class KanbanApp extends StatelessWidget {
  const KanbanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Docket',
      theme: buildDarkTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: createRouter(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: kMaterialSupportedLanguages.map(Locale.new),
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (deviceLocale == null) return supportedLocales.first;

        // If the language is supported
        // keep the full locale (including country)
        final languageSupported = supportedLocales.any(
          (l) => l.languageCode == deviceLocale.languageCode,
        );

        if (languageSupported) return deviceLocale;

        return const Locale('en');
      },
    );
  }
}
