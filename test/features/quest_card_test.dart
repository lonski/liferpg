import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/quests/quest_card.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/quest.dart';
import 'package:liferpg/theme/app_theme.dart';

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

  testWidgets('omits the share button when onShare is not given', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: QuestCard(quest: _quest)),
    ));

    expect(find.byKey(const Key('share-quest-q1')), findsNothing);
  });

  testWidgets('renders a share button that calls onShare when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QuestCard(quest: _quest, onShare: () => tapped = true),
      ),
    ));

    final shareButton = find.byKey(const Key('share-quest-q1'));
    expect(shareButton, findsOneWidget);
    await tester.tap(shareButton);
    expect(tapped, isTrue);
  });

  const dailyQuest = Quest(
    id: 'q2',
    title: 'Wyprowadzić psa',
    posterUid: 'admin1',
    posterEmail: 'admin@example.com',
    posterName: 'Admin',
    status: QuestStatus.assigned,
    reward: ChangeSet(currentXp: 10),
    isDaily: true,
  );

  testWidgets('a live daily quest gets a gold border and the CODZIENNE band', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: QuestCard(quest: dailyQuest)),
    ));

    expect(find.textContaining('CODZIENNE'), findsOneWidget);
    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect((decoration.border as Border).top.color, gold);
  });

  testWidgets('a cancelled (deactivated) daily quest reverts to the ordinary crimson band',
      (tester) async {
    final quest = Quest(
      id: dailyQuest.id,
      title: dailyQuest.title,
      posterUid: dailyQuest.posterUid,
      posterEmail: dailyQuest.posterEmail,
      posterName: dailyQuest.posterName,
      status: QuestStatus.cancelled,
      reward: dailyQuest.reward,
      isDaily: true,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: QuestCard(quest: quest)),
    ));

    expect(find.textContaining('CODZIENNE'), findsNothing);
    expect(find.textContaining('WYCOFANE'), findsOneWidget);
    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect((decoration.border as Border).top.color, crimson);
  });
}
