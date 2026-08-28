/// The live Firestore database was populated by a React web app that wrote
/// numbers and strings interchangeably (JS renders `{gold} zł` identically
/// for 250 and "250"), so these coerce whatever type actually landed there
/// rather than trusting the schema.
num? _asNum(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim());
  return null; // null, bool, Map, List, Timestamp -> null
}

int? _asInt(Object? v) => _asNum(v)?.toInt();

String? _asString(Object? v) => v is String ? v : v?.toString();

class Trait {
  const Trait({required this.name, required this.value});

  final String name;
  final String value;

  factory Trait.fromMap(Map<String, dynamic> data) => Trait(
        name: _asString(data['name']) ?? '',
        value: _asString(data['value']) ?? '',
      );

  Map<String, dynamic> toMap() => {'name': name, 'value': value};
}

class Character {
  const Character({
    required this.id,
    required this.name,
    this.clazz,
    required this.email,
    this.level,
    required this.currentXp,
    required this.nextLevelXp,
    this.gold,
    required this.favour,
    required this.traits,
  });

  final String id;
  final String name;
  final String? clazz;
  final String email;
  final int? level;
  final int currentXp;
  final int nextLevelXp;
  final num? gold;
  final int favour;
  final List<Trait> traits;

  factory Character.fromMap(String id, Map<String, dynamic> data) {
    final rawTraits = data['traits'];
    final traits = rawTraits is List
        ? rawTraits
            .whereType<Map>()
            .map((t) => Trait.fromMap(Map<String, dynamic>.from(t)))
            .toList()
        : const <Trait>[];

    return Character(
      id: id,
      name: _asString(data['name']) ?? '',
      clazz: _asString(data['clazz']),
      email: _asString(data['email']) ?? '',
      level: _asInt(data['level']),
      currentXp: _asInt(data['current_xp']) ?? 0,
      nextLevelXp: _asInt(data['next_level_xp']) ?? 0,
      gold: _asNum(data['gold']),
      favour: _asInt(data['favour']) ?? 0,
      traits: traits,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'clazz': clazz,
        'email': email,
        'level': level,
        'current_xp': currentXp,
        'next_level_xp': nextLevelXp,
        'gold': gold,
        'favour': favour,
        'traits': traits.map((t) => t.toMap()).toList(),
      };

  Character copyWith({
    String? name,
    String? clazz,
    int? level,
    int? currentXp,
    int? nextLevelXp,
    num? gold,
    int? favour,
    List<Trait>? traits,
  }) =>
      Character(
        id: id,
        name: name ?? this.name,
        clazz: clazz ?? this.clazz,
        email: email,
        level: level ?? this.level,
        currentXp: currentXp ?? this.currentXp,
        nextLevelXp: nextLevelXp ?? this.nextLevelXp,
        gold: gold ?? this.gold,
        favour: favour ?? this.favour,
        traits: traits ?? this.traits,
      );

  /// Progress towards the next level, 0.0–1.0, for the XP bar.
  double get xpFraction {
    if (level == null || nextLevelXp <= 0) return 0.0;
    final f = currentXp / nextLevelXp;
    if (f > 1.0) return 1.0;
    if (f < 0.0) return 0.0;
    return f;
  }

  int get xpRemaining => nextLevelXp - currentXp;
}
