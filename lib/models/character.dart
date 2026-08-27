class Trait {
  const Trait({required this.name, required this.value});

  final String name;
  final String value;

  factory Trait.fromMap(Map<String, dynamic> data) => Trait(
        name: data['name'] as String? ?? '',
        value: data['value'] as String? ?? '',
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
    this.goldUsd,
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
  final num? goldUsd;
  final int favour;
  final List<Trait> traits;

  factory Character.fromMap(String id, Map<String, dynamic> data) => Character(
        id: id,
        name: data['name'] as String? ?? '',
        clazz: data['clazz'] as String?,
        email: data['email'] as String? ?? '',
        level: (data['level'] as num?)?.toInt(),
        currentXp: (data['current_xp'] as num?)?.toInt() ?? 0,
        nextLevelXp: (data['next_level_xp'] as num?)?.toInt() ?? 0,
        gold: data['gold'] as num?,
        goldUsd: data['gold_usd'] as num?,
        favour: (data['favour'] as num?)?.toInt() ?? 0,
        traits: ((data['traits'] as List<dynamic>?) ?? const [])
            .map((t) => Trait.fromMap(Map<String, dynamic>.from(t as Map)))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'clazz': clazz,
        'email': email,
        'level': level,
        'current_xp': currentXp,
        'next_level_xp': nextLevelXp,
        'gold': gold,
        'gold_usd': goldUsd,
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
    num? goldUsd,
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
        goldUsd: goldUsd ?? this.goldUsd,
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
