/// The custom-scheme link a shared quest carries, and the matching parser
/// `main.dart` feeds incoming `app_links` URIs through. Kept as pure
/// functions, free of any plugin/platform dependency, so both directions are
/// unit-testable without touching `app_links` itself.
library;

String questDeepLink(String questId) => 'liferpg://quest/$questId';

/// Returns the quest id carried by a `liferpg://quest/<id>` URI, or `null`
/// if [uri] doesn't match that shape.
String? questIdFromDeepLink(Uri uri) {
  if (uri.scheme != 'liferpg' || uri.host != 'quest') return null;
  if (uri.pathSegments.isEmpty) return null;
  final id = uri.pathSegments.first;
  return id.isEmpty ? null : id;
}
