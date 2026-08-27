class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.admin,
    required this.readOnlyOthers,
  });

  final String uid;
  final String name;
  final String email;
  final bool admin;
  final bool readOnlyOthers;

  /// The live Firestore database was populated by a React web app that wrote
  /// booleans and strings interchangeably, so this coerces whatever type
  /// actually landed there rather than trusting the schema.
  static bool _asBool(Object? v) {
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    if (v is num) return v != 0;
    return false;
  }

  static String? _asString(Object? v) => v is String ? v : v?.toString();

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) => AppUser(
        uid: uid,
        name: _asString(data['name']) ?? '',
        email: _asString(data['email']) ?? '',
        admin: _asBool(data['admin']),
        readOnlyOthers: _asBool(data['readOnlyOthers']),
      );

  /// Admins and readOnlyOthers users see the whole roster; everyone else sees
  /// only the characters carrying their own email.
  bool get canSeeAllCharacters => admin || readOnlyOthers;

  /// Editing is admin-only. readOnlyOthers deliberately does not grant it.
  bool get canEdit => admin;
}
