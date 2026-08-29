/// Which of `items` are newly present since the last check, and the id set
/// to persist afterwards. Generic over three quest events that all share
/// the exact same "notify on newly-appearing id, seed silently on the first
/// ever check" shape that `diffPendingRequests` established for change
/// requests -- kept as one generic helper here instead of three near-copies.
class IdDiff<T> {
  const IdDiff({required this.toNotify, required this.notifiedIds});

  final List<T> toNotify;
  final Set<String> notifiedIds;
}

IdDiff<T> diffNewIds<T>({
  required List<T> items,
  required String Function(T) idOf,
  required Set<String>? previouslyNotified,
}) {
  final currentIds = items.map(idOf).toSet();
  if (previouslyNotified == null) {
    return IdDiff(toNotify: const [], notifiedIds: currentIds);
  }
  final toNotify = items.where((i) => !previouslyNotified.contains(idOf(i))).toList();
  return IdDiff(toNotify: toNotify, notifiedIds: currentIds);
}
