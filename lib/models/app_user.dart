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

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) => AppUser(
        uid: uid,
        name: data['name'] as String? ?? '',
        email: data['email'] as String? ?? '',
        admin: data['admin'] as bool? ?? false,
        readOnlyOthers: data['readOnlyOthers'] as bool? ?? false,
      );

  /// Admins and readOnlyOthers users see the whole roster; everyone else sees
  /// only the characters carrying their own email.
  bool get canSeeAllCharacters => admin || readOnlyOthers;

  /// Editing is admin-only. readOnlyOthers deliberately does not grant it.
  bool get canEdit => admin;
}
