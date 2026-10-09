import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The wall clock. Overridden in tests so day boundaries are deterministic;
/// new code reads this instead of calling DateTime.now() directly.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
