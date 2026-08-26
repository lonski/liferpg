import 'package:flutter/material.dart';

import '../../models/character.dart';

class EditCharacterScreen extends StatelessWidget {
  const EditCharacterScreen({super.key, required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(), body: Center(child: Text(character.name)));
}
