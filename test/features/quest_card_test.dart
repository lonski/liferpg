import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/quests/quest_card.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/quest.dart';

const _quest = Quest(
  id: 'q1',
  title: 'Posprzątaj garaż',
  posterUid: 'u1',
  posterEmail: 'ala@example.com',
  posterName: 'Ala',
  status: QuestStatus.open,
  reward: ChangeSet(currentXp: 50, traits: [TraitChange(name: 'Porządek', value: '+1')]),
);

void main() {
  testWidgets('renders the title, reward pills, caption, and actions', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QuestCard(
          quest: _quest,
          posterOrHolderLine: 'Wystawione przez: Ala',
          actions: [TextButton(key: const Key('take'), onPressed: () {}, child: const Text('Podejmij'))],
        ),
      ),
    ));

    expect(find.text('Posprzątaj garaż'), findsOneWidget);
    expect(find.textContaining('+50 XP'), findsOneWidget);
    expect(find.textContaining('Porządek'), findsOneWidget);
    expect(find.text('Wystawione przez: Ala'), findsOneWidget);
    expect(find.byKey(const Key('take')), findsOneWidget);
  });

  testWidgets('renders a status badge when given one and no actions', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QuestCard(
          quest: _quest,
          statusBadge: const Text('OCZEKUJE NA AKCEPTACJĘ'),
        ),
      ),
    ));

    expect(find.text('OCZEKUJE NA AKCEPTACJĘ'), findsOneWidget);
  });
}
