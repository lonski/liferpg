import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/boss.dart';
import '../models/character.dart';
import '../models/character_deltas.dart';

class BossGone implements Exception {
  const BossGone();

  @override
  String toString() => 'Tego bossa już nie ma';
}

class BossCharacterGone implements Exception {
  const BossCharacterGone();

  @override
  String toString() => 'Postać już nie istnieje';
}

class NotEnoughEnergy implements Exception {
  const NotEnoughEnergy(this.available);

  final int available;

  @override
  String toString() => 'Za mało energii bojowej ($available)';
}

class BossRewardNotAvailable implements Exception {
  const BossRewardNotAvailable();

  @override
  String toString() => 'Nagroda została już odebrana';
}

/// What one blow did, for the fight animation.
class AttackOutcome {
  const AttackOutcome({
    required this.damage,
    required this.hp,
    required this.defeated,
  });

  final int damage;
  final int hp;
  final bool defeated;
}

/// The bosses collection. There are no Cloud Functions: every write runs on
/// a client, the attacker's or the claimant's own, and firestore.rules is
/// what keeps those writes honest (see the bosses match there).
class BossRepository {
  BossRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _bosses =>
      _db.collection('bosses');

  /// Live and beaten bosses -- a beaten one stays until every fighter has
  /// collected. Readable by everyone signed in, like the quest board.
  Stream<List<Boss>> watchLive() => _bosses
      .where(
        'status',
        whereIn: [BossStatus.active.name, BossStatus.defeated.name],
      )
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) {
              try {
                return Boss.fromMap(d.id, d.data());
              } catch (e) {
                debugPrint('Skipping malformed boss ${d.id}: $e');
                return null;
              }
            })
            .whereType<Boss>()
            .toList(),
      );

  /// An admin calls a boss onto [targets]' cards (the whole roster for
  /// "everyone", or the one chosen character). Each target's current XP
  /// becomes its baseline, so energy counts only XP earned from now on.
  Future<void> summon({
    required String name,
    required BossLook look,
    required int hp,
    required BossReward reward,
    required Character? target,
    required List<Character> targets,
    required String createdBy,
    required String createdByName,
  }) => _bosses.add({
    'name': name,
    'look': look.name,
    'maxHp': hp,
    'hp': hp,
    'reward': reward.toMap(),
    'targetCharacterId': target?.id,
    'targetCharacterName': target?.name,
    'status': BossStatus.active.name,
    'createdAt': FieldValue.serverTimestamp(),
    'createdBy': createdBy,
    'createdByName': createdByName,
    'baseline': {for (final c in targets) c.id: c.currentXp},
    'spent': <String, int>{},
    'damage': <String, int>{},
    'rewarded': <String, bool>{},
  });

  /// A character created after the boss appeared joins with its current XP
  /// as baseline. A no-op once it has one, or once the boss is gone.
  Future<void> join(String bossId, String characterId) async {
    final bossRef = _bosses.doc(bossId);
    final charRef = _db.collection('characters').doc(characterId);
    await _db.runTransaction((tx) async {
      final boss = (await tx.get(bossRef)).data();
      final character = (await tx.get(charRef)).data();
      if (boss == null || character == null) return;
      final parsed = Boss.fromMap(bossId, boss);
      if (!parsed.isActive ||
          !parsed.targets(characterId) ||
          parsed.baseline.containsKey(characterId)) {
        return;
      }
      tx.update(bossRef, {
        'baseline': {...parsed.baseline, characterId: _xpOf(character)},
        'lastJoinedId': characterId,
      });
    });
  }

  /// One blow by [characterId]. Re-reads both documents so a stale screen
  /// can neither spend energy twice nor hit a boss somebody else just beat.
  Future<AttackOutcome> attack({
    required String bossId,
    required String characterId,
    required String characterName,
    required BlowTier tier,
  }) async {
    final bossRef = _bosses.doc(bossId);
    final charRef = _db.collection('characters').doc(characterId);
    return _db.runTransaction((tx) async {
      final bossData = (await tx.get(bossRef)).data();
      if (bossData == null) throw const BossGone();
      final charData = (await tx.get(charRef)).data();
      if (charData == null) throw const BossCharacterGone();
      final boss = Boss.fromMap(bossId, bossData);
      if (!boss.isActive || !boss.targets(characterId)) throw const BossGone();
      final base = boss.baseline[characterId];
      final spent = boss.spent[characterId] ?? 0;
      final energy = base == null
          ? 0
          : math.max(0, _xpOf(charData) - base - spent);
      if (energy < tier.cost) throw NotEnoughEnergy(energy);

      final hp = math.max(0, boss.hp - tier.damage);
      final defeated = hp == 0;
      tx.update(bossRef, {
        'hp': hp,
        'spent': {...boss.spent, characterId: spent + tier.cost},
        'damage': {
          ...boss.damage,
          characterId: boss.damageBy(characterId) + tier.damage,
        },
        'lastAttackerId': characterId,
        'lastAttackerName': characterName,
        if (defeated) 'status': BossStatus.defeated.name,
        if (defeated) 'defeatedAt': FieldValue.serverTimestamp(),
      });
      return AttackOutcome(damage: tier.damage, hp: hp, defeated: defeated);
    });
  }

  /// Pays [characterId] the beaten boss's reward and marks it collected, in
  /// one transaction, so a double tap cannot pay twice.
  Future<BossReward> claimReward(String bossId, String characterId) async {
    final bossRef = _bosses.doc(bossId);
    final charRef = _db.collection('characters').doc(characterId);
    return _db.runTransaction((tx) async {
      final bossData = (await tx.get(bossRef)).data();
      if (bossData == null) throw const BossGone();
      final charData = (await tx.get(charRef)).data();
      if (charData == null) throw const BossCharacterGone();
      final boss = Boss.fromMap(bossId, bossData);
      if (!boss.rewardWaitingFor(characterId)) {
        throw const BossRewardNotAvailable();
      }
      tx.update(charRef, {
        ...applyCharacterDeltas(charData, boss.reward.toChangeSet()),
        'lastBossRewardId': bossId,
      });
      final rewarded = bossData['rewarded'];
      tx.update(bossRef, {
        'rewarded': {
          if (rewarded is Map) ...Map<String, dynamic>.from(rewarded),
          characterId: true,
        },
        'lastClaimId': characterId,
      });
      return boss.reward;
    });
  }

  /// An admin calls the boss off; it leaves every card.
  Future<void> cancel(String bossId) =>
      _bosses.doc(bossId).update({'status': BossStatus.cancelled.name});

  int _xpOf(Map<String, dynamic> character) {
    final v = character['current_xp'];
    if (v is num) return v.toInt();
    if (v is String) return num.tryParse(v.trim())?.toInt() ?? 0;
    return 0;
  }
}
