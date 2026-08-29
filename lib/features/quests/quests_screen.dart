import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class QuestsScreen extends StatelessWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: bgDark,
        appBar: AppBar(title: const Text('Zadania')),
        body: const SizedBox(),
      );
}
