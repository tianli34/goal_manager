import 'package:flutter/material.dart';

import 'app_shell.dart';

void goHome(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
  AppShell.homeKey.currentState?.selectHomeTab();
}

class HomeButton extends StatelessWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '回到主页',
      icon: const Icon(Icons.home_outlined),
      onPressed: () => goHome(context),
    );
  }
}
