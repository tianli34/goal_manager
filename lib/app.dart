import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/repository.dart';
import 'ui/app_shell.dart';
import 'ui/home.dart';
import 'ui/scope.dart';
import 'ui/theme.dart';

class GoalManagerApp extends StatelessWidget {
  const GoalManagerApp({super.key, required this.repository});

  final GoalRepository repository;

  @override
  Widget build(BuildContext context) {
    return RepositoryScope(
      repository: repository,
      child: MaterialApp(
        title: '北极星',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        navigatorObservers: [HomeDepthObserver.instance],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AppShell(key: AppShell.homeKey),
      ),
    );
  }
}
