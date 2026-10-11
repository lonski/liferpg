import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'change_request.dart' show ChangeSet, TraitChange;
import 'character.dart';

// Written only by this app, but coerced in the style of Character.fromMap
// rather than trusted.
int? _asInt(Object? v) {
  if (v is num) return v.isFinite ? v.toInt() : null;
  if (v is String) return num.tryParse(v.trim())?.toInt();
  return null;
}

num? _asNum(Object? v) {
  final n = v is num ? v : (v is String ? num.tryParse(v.trim()) : null);
  return n != null && n.isFinite ? n : null;
}

String? _asText(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

Map<String, int> _intMap(Object? raw) => {
  if (raw is Map)
    for (final e in raw.entries)
      if (e.key is String && _asInt(e.value) != null)
        e.key as String: _asInt(e.value)!,
};

/// What a boss looks like. The persisted value is [name]; the drawing is
/// `assets/bosses/<name>.svg`.
enum BossLook {
  smok('Smok Ognisty', 'zieje ogniem, kocha złoto'),
  rycerz('Czarny Rycerz', 'nigdy nie zdejmuje hełmu'),
  wiedzma('Wiedźma z Bagien', 'warzy kłopoty w kociołku'),
  upior('Upiór Zamkowy', 'straszy po dobranocce'),
  troll('Troll Mostowy', 'pobiera myto za przejście'),
  golem('Kamienny Golem', 'powolny, ale twardy'),
  kosciej('Król Kościej', 'nieśmiertelny… prawie'),
  kraken('Kraken', 'mieszka w wannie');

  const BossLook(this.label, this.tagline);

  /// The default name the summon form fills in.
  final String label;
  final String tagline;

  String get asset => 'assets/bosses/$name.svg';

  static BossLook parse(Object? v) =>
      values.firstWhere((l) => l.name == v, orElse: () => smok);
}

/// One of the four blow strengths every weapon has: the energy it costs and
/// the damage it deals. The bigger tiers pay a bonus (50 → 60, 100 → 150).
enum BlowTier {
  basic(1, 1, 'zwykłe uderzenie'),
  strong(10, 10, 'mocniejszy cios'),
  combo(50, 60, 'combo'),
  hyper(100, 150, 'hipercios');

  const BlowTier(this.cost, this.damage, this.kind);

  final int cost;
  final int damage;
  final String kind;

  /// The tier a (cost, damage) pair belongs to, or null for any other pair
  /// -- mirrors the attack rule in firestore.rules.
  static BlowTier? of(int cost, int damage) {
    for (final t in values) {
      if (t.cost == cost && t.damage == damage) return t;
    }
    return null;
  }
}

class Blow {
  const Blow(this.tier, this.name, this.flavor);

  final BlowTier tier;
  final String name;
  final String flavor;
}

/// What a character fights with. The persisted value is [name].
enum Weapon {
  miecz('Miecz', [
    Blow(BlowTier.basic, 'Cięcie', 'Krótko i na temat.'),
    Blow(BlowTier.strong, 'Mocne cięcie', 'Z zamachem zza ucha.'),
    Blow(BlowTier.combo, 'Wir ostrzy', 'Kręci się ostrze, kręci się boss.'),
    Blow(BlowTier.hyper, 'Ostrze burzy', 'Piorun w stali. Grzmi aż miło.'),
  ]),
  luk('Łuk', [
    Blow(BlowTier.basic, 'Strzała', 'Jedna, ale celna.'),
    Blow(BlowTier.strong, 'Celny strzał', 'Prosto w słaby punkt.'),
    Blow(BlowTier.combo, 'Grad strzał', 'Niebo zrobiło się pierzaste.'),
    Blow(BlowTier.hyper, 'Strzała gromu', 'Leci szybciej niż własny huk.'),
  ]),
  maczuga('Maczuga', [
    Blow(BlowTier.basic, 'Walnięcie', 'Proste i skuteczne.'),
    Blow(BlowTier.strong, 'Potężne walnięcie', 'Aż echo poszło.'),
    Blow(BlowTier.combo, 'Trzęsienie ziemi', 'Podłoga też dostała.'),
    Blow(BlowTier.hyper, 'Miażdżący cios', 'Po tym zostaje tylko placek.'),
  ]),
  miotla('Miotła', [
    Blow(BlowTier.basic, 'Zamach miotłą', 'Sio, sio!'),
    Blow(BlowTier.strong, 'Kurz w oczy', 'Kto nie sprząta, ten kicha.'),
    Blow(BlowTier.combo, 'Wielkie zamiatanie', 'Boss pod dywan!'),
    Blow(
      BlowTier.hyper,
      'Tornado porządków',
      'Wiosenne porządki w pełnej mocy.',
    ),
  ]),
  ksiega('Księga zaklęć', [
    Blow(
      BlowTier.basic,
      'Iskra',
      'Mała, ale złośliwa iskierka. Łaskocze nawet smoki.',
    ),
    Blow(
      BlowTier.strong,
      'Kula ognia',
      'Klasyka gatunku. Ciepło, cieplej, gorąco!',
    ),
    Blow(
      BlowTier.combo,
      'Lodowa burza',
      'Zamraża łuski i dobry humor przeciwnika.',
    ),
    Blow(
      BlowTier.hyper,
      'Deszcz meteorów',
      'Gdy niebo spada bossowi prosto na głowę.',
    ),
  ]);

  const Weapon(this.label, this.blows);

  final String label;
  final List<Blow> blows;

  String get asset => 'assets/bosses/weapon_$name.svg';

  static Weapon? parse(Object? v) {
    for (final w in values) {
      if (w.name == v) return w;
    }
    return null;
  }

  /// The weapon a class fights with unless the admin picks another, or null
  /// when the class has none.
  static Weapon? forClass(String? clazz) {
    final c = (clazz ?? '').trim().toLowerCase();
    if (c.startsWith('barbarzy')) return maczuga;
    if (c == 'pani domu') return miotla;
    if (c.startsWith('czarodziej')) return ksiega;
    return null;
  }
}

/// The weapon [character] fights with: the admin's choice, else its
/// class's default, else none.
Weapon? weaponOf(Character character) =>
    character.weapon ?? Weapon.forClass(character.clazz);

/// Deltas with change-request semantics (traits matched by name, added),
/// paid to every character that damaged the boss.
class BossReward {
  const BossReward({this.currentXp, this.gold, this.traits = const []});

  final int? currentXp;
  final num? gold;
  final List<TraitChange> traits;

  bool get isEmpty => currentXp == null && gold == null && traits.isEmpty;

  factory BossReward.fromMap(Object? raw) {
    if (raw is! Map) return const BossReward();
    final rawTraits = raw['traits'];
    return BossReward(
      currentXp: _asNum(raw['current_xp'])?.toInt(),
      gold: _asNum(raw['gold']),
      traits: [
        if (rawTraits is List)
          for (final t in rawTraits.whereType<Map>())
            TraitChange.fromMap(Map<String, dynamic>.from(t)),
      ].where((t) => t.name.trim().isNotEmpty).toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    if (currentXp != null) 'current_xp': currentXp,
    if (gold != null) 'gold': gold,
    if (traits.isNotEmpty) 'traits': [for (final t in traits) t.toMap()],
  };

  ChangeSet toChangeSet() =>
      ChangeSet(currentXp: currentXp, gold: gold, traits: traits);

  /// "+50 XP", "+20 zł", "Odwaga +1" -- for chips and captions.
  List<String> get parts => [
    if (currentXp != null) '${_signed(currentXp!)} XP',
    if (gold != null) '${_signed(gold!)} zł',
    for (final t in traits)
      '${t.name} ${_signed(num.tryParse(t.value.trim()) ?? 0)}',
  ];
}

String _signed(num n) {
  final text = n % 1 == 0 ? n.toInt().toString() : '$n';
  return n >= 0 ? '+$text' : text;
}

enum BossStatus {
  active,
  defeated,
  cancelled;

  static BossStatus parse(Object? v) =>
      values.firstWhere((s) => s.name == v, orElse: () => cancelled);
}

class Boss {
  const Boss({
    required this.id,
    required this.name,
    required this.look,
    required this.maxHp,
    required this.hp,
    this.reward = const BossReward(),
    this.targetCharacterId,
    this.targetCharacterName,
    this.status = BossStatus.active,
    this.createdAt,
    this.createdBy = '',
    this.createdByName = '',
    this.baseline = const {},
    this.spent = const {},
    this.damage = const {},
    this.rewarded = const {},
    this.lastAttackerName,
  });

  final String id;
  final String name;
  final BossLook look;
  final int maxHp;
  final int hp;
  final BossReward reward;

  /// Null: every character fights it.
  final String? targetCharacterId;
  final String? targetCharacterName;
  final BossStatus status;
  final DateTime? createdAt;
  final String createdBy;
  final String createdByName;

  /// Each character's current_xp when the boss appeared (or when it first
  /// joined, for a character created later).
  final Map<String, int> baseline;
  final Map<String, int> spent;
  final Map<String, int> damage;
  final Set<String> rewarded;
  final String? lastAttackerName;

  factory Boss.fromMap(String id, Map<String, dynamic> data) {
    final maxHp = math.max(1, _asInt(data['maxHp']) ?? 1);
    final created = data['createdAt'];
    final rawRewarded = data['rewarded'];
    return Boss(
      id: id,
      name: _asText(data['name']) ?? BossLook.parse(data['look']).label,
      look: BossLook.parse(data['look']),
      maxHp: maxHp,
      hp: (_asInt(data['hp']) ?? maxHp).clamp(0, maxHp),
      reward: BossReward.fromMap(data['reward']),
      targetCharacterId: _asText(data['targetCharacterId']),
      targetCharacterName: _asText(data['targetCharacterName']),
      status: BossStatus.parse(data['status']),
      createdAt: created is Timestamp ? created.toDate() : null,
      createdBy: _asText(data['createdBy']) ?? '',
      createdByName: _asText(data['createdByName']) ?? '',
      baseline: _intMap(data['baseline']),
      spent: _intMap(data['spent']),
      damage: _intMap(data['damage']),
      rewarded: {
        if (rawRewarded is Map)
          for (final e in rawRewarded.entries)
            if (e.key is String && e.value == true) e.key as String,
      },
      lastAttackerName: _asText(data['lastAttackerName']),
    );
  }

  bool get isActive => status == BossStatus.active;
  bool get isDefeated => status == BossStatus.defeated;
  double get hpFraction => hp / maxHp;

  bool targets(String characterId) =>
      targetCharacterId == null || targetCharacterId == characterId;

  /// Energy left for [character]: XP gained since the boss appeared, minus
  /// what its blows used. Null until the character has a baseline.
  int? energyOf(Character character) {
    final base = baseline[character.id];
    if (base == null) return null;
    return math.max(0, character.currentXp - base - (spent[character.id] ?? 0));
  }

  int damageBy(String characterId) => damage[characterId] ?? 0;

  /// Beaten, damaged by [characterId], reward not yet collected.
  bool rewardWaitingFor(String characterId) =>
      isDefeated &&
      damageBy(characterId) > 0 &&
      !rewarded.contains(characterId);

  /// Fighters by damage dealt, biggest first.
  List<MapEntry<String, int>> get fighters =>
      damage.entries.where((e) => e.value > 0).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
}

/// The bosses to show under [character]'s card: live ones it may fight,
/// and beaten ones whose reward it still has to collect. Oldest first.
List<Boss> bossesFor(List<Boss> bosses, Character character) =>
    bosses
        .where(
          (b) =>
              (b.isActive && b.targets(character.id)) ||
              b.rewardWaitingFor(character.id),
        )
        .toList()
      ..sort((a, b) {
        final at = a.createdAt, bt = b.createdAt;
        if (at == null || bt == null) {
          return at == null ? (bt == null ? 0 : 1) : -1;
        }
        return at.compareTo(bt);
      });
