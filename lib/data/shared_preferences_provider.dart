import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The seam through which tests swap in a mock-backed instance. `main()`
/// awaits `SharedPreferences.getInstance()` before `runApp` (the same shape
/// as Firestore persistence setup) and overrides this provider with the
/// result, since obtaining an instance is asynchronous and a `ProviderScope`
/// override must be synchronous.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main() with a real '
    'SharedPreferences instance obtained before runApp().',
  );
});
