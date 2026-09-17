/// The link a shared quest carries, and the matching parser `main.dart`
/// feeds incoming `app_links` URIs through. Kept as pure functions, free of
/// any plugin/platform dependency, so both directions are unit-testable
/// without touching `app_links` itself.
///
/// Two URI shapes are recognized: the current `https://` shape (a verified
/// Android App Link, see `docs/superpowers/specs/
/// 2026-09-17-quest-deep-link-app-links-design.md`) and the original
/// `liferpg://` custom scheme, kept for back-compat with already-shared
/// links and because the hosted fallback page still redirects through it.
library;

const _httpsHost = 'liferpg.lonski.pl';

String questDeepLink(String questId) => 'https://$_httpsHost/quest/$questId';

/// Returns the quest id carried by a matching link, or `null` if [uri]
/// doesn't match either recognized shape.
String? questIdFromDeepLink(Uri uri) {
  if (uri.scheme == 'https' && uri.host == _httpsHost) {
    final segments = uri.pathSegments;
    if (segments.length < 2 || segments[0] != 'quest') return null;
    final id = segments[1];
    return id.isEmpty ? null : id;
  }
  if (uri.scheme == 'liferpg' && uri.host == 'quest') {
    if (uri.pathSegments.isEmpty) return null;
    final id = uri.pathSegments.first;
    return id.isEmpty ? null : id;
  }
  return null;
}
