# Change Request Lifecycle Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix a card-layout bug, add a reject confirmation, let admins restore
a rejected request to pending, require a reason on new requests, let
requesters cancel their own pending requests, and remove the unused
`gold_usd` ("Dolary") currency field entirely.

**Architecture:** All work is in the existing Flutter/Firestore change-request
feature (`lib/models/change_request.dart`, `lib/data/change_request_repository.dart`,
`lib/features/requests/*`) plus a small removal sweep through
`lib/models/character.dart` and `lib/features/character/*`. One new shared
widget file (`lib/theme/dialogs.dart`) is added for a reusable confirm
dialog. One `firestore.rules` clause is added, with matching emulator tests.

**Tech Stack:** Flutter/Dart, Riverpod, `fake_cloud_firestore` +
`firebase_auth_mocks` for widget/unit tests, `@firebase/rules-unit-testing`
(Node) for the Firestore rules emulator tests.

**Spec:** `docs/superpowers/specs/2026-08-28-change-request-lifecycle-design.md`

## Global Constraints

- Firestore field names stay snake_case (`gold`, `current_xp`, ...); Dart-side
  names are camelCase, mapped in `fromMap`/`toMap`.
- The UI is Polish; never translate existing labels, and any new copy
  (dialog titles, button labels) must be Polish and match the existing tone
  (short, capitalized via `.toUpperCase()` at the point of use for
  display-styled text, normal-case Dart string literals).
- Never touch `FirebaseAuth.instance` / `FirebaseFirestore.instance` outside
  `lib/data/firebase_providers.dart`.
- Run `flutter test` after every task; run `flutter analyze` after the final
  task. Rules changes are validated with, from the repo root:
  `npx --yes firebase-tools emulators:exec --only firestore --project liferpg-rules-test "npm --prefix tools/rules-test test"`
  (needs a JDK on `PATH`; if `npm ci --legacy-peer-deps` has never been run
  in `tools/rules-test`, run that first).
- Never dispatch or invoke a subagent, and never call any code-review skill,
  from inside an implementer task — review happens between tasks, run by the
  controller.

---

### Task 1: Fix the full-width request card bug

**Files:**
- Modify: `lib/features/requests/change_requests_screen.dart`
- Test: `test/features/change_requests_screen_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing new — pure layout fix, no API change.

- [ ] **Step 1: Write the failing test**

Add to `test/features/change_requests_screen_test.dart` (inside `main()`,
after the existing `'a decided request offers no accept/reject/edit actions'`
test):

```dart
  testWidgets(
      'a decided request card spans the same width as a pending one',
      (tester) async {
    final db = await seed();
    final decided = await db.collection('change_requests').add({
      'characterId': characterId,
      'characterName': 'T',
      'requesterUid': 'u2',
      'requesterEmail': 'bob@example.com',
      'status': 'rejected',
      'changes': {'gold': 5},
    });
    await pumpScreen(tester, db);

    final pendingWidth =
        tester.getSize(find.byKey(Key('request-$requestId'))).width;

    await tester.tap(find.byKey(const Key('filter-rejected')));
    await tester.pumpAndSettle();

    final rejectedWidth =
        tester.getSize(find.byKey(Key('request-${decided.id}'))).width;

    // Both cards live in the same ListView with the same horizontal padding,
    // so their outer widths already match -- the bug shrank only the inner
    // crimson-bordered content box. Measure that inner box directly via its
    // decoration: it's the widget carrying `crimsonBorder`.
    final innerBox = tester.widgetList<Container>(find.descendant(
      of: find.byKey(Key('request-${decided.id}')),
      matching: find.byType(Container),
    )).firstWhere((c) {
      final decoration = c.decoration;
      return decoration is BoxDecoration &&
          decoration.border == Border.all(color: crimsonBorder);
    });
    final innerWidth =
        tester.renderObject<RenderBox>(find.byWidget(innerBox)).size.width;

    expect(rejectedWidth, pendingWidth);
    // Before the fix this was far smaller than the card (shrink-wrapped to
    // "T" / the timestamp / "Złoto: +5" -- the widest line was well under
    // half the card width on a typical test viewport).
    expect(innerWidth, greaterThan(rejectedWidth * 0.9));
  });
```

Add `import 'package:flutter/rendering.dart';` to the top of the test file if
`RenderBox` is not already visible through `package:flutter/material.dart`
(it is exported transitively in current Flutter, so this import is only
needed if analysis complains).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/change_requests_screen_test.dart`
Expected: FAIL on the `innerWidth` expectation (the inner box is shrink-wrapped).

- [ ] **Step 3: Fix the widget**

In `lib/features/requests/change_requests_screen.dart`, inside
`_RequestCard.build()`, find:

```dart
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: crimsonBorder),
                borderRadius: BorderRadius.circular(2),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
```

Replace with:

```dart
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: crimsonBorder),
                borderRadius: BorderRadius.circular(2),
              ),
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/change_requests_screen_test.dart`
Expected: PASS, all tests in the file.

- [ ] **Step 5: Commit**

```bash
git add lib/features/requests/change_requests_screen.dart test/features/change_requests_screen_test.dart
git commit -m "fix: make request cards fill the width when no action row renders"
```

---

### Task 2: Confirm before reject (shared confirm dialog)

**Files:**
- Create: `lib/theme/dialogs.dart`
- Modify: `lib/features/requests/change_requests_screen.dart`
- Test: `test/features/change_requests_screen_test.dart`

**Interfaces:**
- Produces: `Future<bool> showConfirmDialog(BuildContext context, {required String title, required String cancelLabel, required String confirmLabel, required Key confirmKey})` in `lib/theme/dialogs.dart` — returns `true` only if the button keyed `confirmKey` was tapped, `false` for cancel or dismissal. **Task 5 (cancel) consumes this exact signature — do not change it without checking that task.**

- [ ] **Step 1: Write the failing test**

Add to `test/features/change_requests_screen_test.dart`, replacing the
existing `'rejecting marks the request without touching the character'` test
with:

```dart
  testWidgets('rejecting asks for confirmation before marking the request',
      (tester) async {
    final db = await seed();
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(Key('reject-$requestId')));
    await tester.pumpAndSettle();

    // Not yet decided -- the confirm dialog is up, nothing has happened.
    var request =
        (await db.collection('change_requests').doc(requestId).get()).data()!;
    expect(request['status'], 'pending');

    await tester.tap(find.byKey(Key('confirm-reject-$requestId')));
    await tester.pumpAndSettle();

    request =
        (await db.collection('change_requests').doc(requestId).get()).data()!;
    expect(request['status'], 'rejected');
    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['current_xp'], 40);
  });

  testWidgets('backing out of the reject confirmation changes nothing',
      (tester) async {
    final db = await seed();
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(Key('reject-$requestId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ANULUJ'));
    await tester.pumpAndSettle();

    final request =
        (await db.collection('change_requests').doc(requestId).get()).data()!;
    expect(request['status'], 'pending');
    expect(find.byKey(Key('request-$requestId')), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/change_requests_screen_test.dart`
Expected: FAIL — tapping `reject-$requestId` currently rejects immediately,
so `confirm-reject-$requestId` and the `'ANULUJ'` text never appear (finds
nothing / times out).

- [ ] **Step 3: Create the shared confirm dialog**

Create `lib/theme/dialogs.dart`:

```dart
import 'package:flutter/material.dart';

import 'app_theme.dart';

const TextStyle _dialogAction = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 10,
  fontWeight: FontWeight.w700,
  letterSpacing: 2,
);

/// A parchment-surfaced yes/no confirmation, styled like the app's other
/// admin dialogs (crimson-bordered parchment card, gold-glyph confirm
/// button) so a confirm step never reads as a foreign widget dropped onto
/// the dark scaffold. Returns `true` only if [confirmKey]'s button was
/// tapped; `false` for "cancel" or dismissing the dialog any other way.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String cancelLabel,
  required String confirmLabel,
  required Key confirmKey,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: parchment,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: crimson, width: 2),
      ),
      title: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: fontDisplay,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: inkHeading,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: TextButton.styleFrom(foregroundColor: crimson),
          child: Text(cancelLabel.toUpperCase(), style: _dialogAction),
        ),
        TextButton(
          key: confirmKey,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            backgroundColor: crimson,
            foregroundColor: parchmentLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
              side: const BorderSide(color: goldGlyph),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: Text(confirmLabel.toUpperCase(), style: _dialogAction),
        ),
      ],
    ),
  );
  return result ?? false;
}
```

- [ ] **Step 4: Wire it into reject**

In `lib/features/requests/change_requests_screen.dart`, add the import:

```dart
import '../../theme/dialogs.dart';
```

Add this method to `_ChangeRequestsScreenState`, right after `_decide`:

```dart
  Future<void> _confirmAndReject(ChangeRequest request, String adminUid) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Odrzucić prośbę?',
      cancelLabel: 'Anuluj',
      confirmLabel: 'Odrzuć',
      confirmKey: Key('confirm-reject-${request.id}'),
    );
    if (!confirmed) return;
    await _decide(
      () => ref
          .read(changeRequestRepositoryProvider)
          .reject(request, adminUid: adminUid),
      'Prośba odrzucona',
    );
  }
```

Then change the `onReject` wiring in `build()` from:

```dart
                                  onReject: () => _decide(
                                    () => ref
                                        .read(changeRequestRepositoryProvider)
                                        .reject(request, adminUid: adminUid),
                                    'Prośba odrzucona',
                                  ),
```

to:

```dart
                                  onReject: () =>
                                      _confirmAndReject(request, adminUid),
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/change_requests_screen_test.dart`
Expected: PASS, all tests in the file.

- [ ] **Step 6: Commit**

```bash
git add lib/theme/dialogs.dart lib/features/requests/change_requests_screen.dart test/features/change_requests_screen_test.dart
git commit -m "feat: confirm before rejecting a change request"
```

---

### Task 3: Restore a rejected request to pending

**Files:**
- Modify: `lib/data/change_request_repository.dart`
- Modify: `lib/features/requests/change_requests_screen.dart`
- Test: `test/data/change_request_repository_test.dart`
- Test: `test/features/change_requests_screen_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `ChangeRequestRepository.restoreToPending(ChangeRequest request)` (throws `ChangeRequestNotRejected` if the request is not currently rejected) and the `ChangeRequestNotRejected` exception class, both in `lib/data/change_request_repository.dart`.

- [ ] **Step 1: Write the failing repository tests**

Add to `test/data/change_request_repository_test.dart`, after the
`'reject marks the request without touching the character'` test:

```dart
  test('restoreToPending flips a rejected request back to pending',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db);
    await repo.create(_request(characterId: characterId));
    await repo.reject(await onlyRequest(db), adminUid: 'admin1');

    await repo.restoreToPending(await onlyRequest(db));

    final restored = await onlyRequest(db);
    expect(restored.status, ChangeRequestStatus.pending);
    expect(restored.decidedBy, isNull);
    expect(restored.decidedAt, isNull);
  });

  test('restoreToPending throws if the request is not rejected', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db);
    await repo.create(_request(characterId: characterId));

    await expectLater(
      repo.restoreToPending(await onlyRequest(db)),
      throwsA(isA<ChangeRequestNotRejected>()),
    );
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/change_request_repository_test.dart`
Expected: FAIL with "The method 'restoreToPending' isn't defined" (compile error).

- [ ] **Step 3: Implement the repository method**

In `lib/data/change_request_repository.dart`, add this class after
`ChangeRequestCharacterGone`:

```dart
/// Thrown when `restoreToPending` finds the request is not currently
/// rejected -- someone already restored or re-decided it since the admin's
/// list last refreshed.
class ChangeRequestNotRejected implements Exception {
  const ChangeRequestNotRejected();

  @override
  String toString() => 'Ta prośba nie jest już odrzucona';
}
```

Add this method after `reject`:

```dart
  /// Puts a rejected request back in the queue, as if it had never been
  /// decided. There is no `decidedBy`/`decidedAt` afterwards -- restoring is
  /// not itself a decision.
  Future<void> restoreToPending(ChangeRequest request) async {
    final requestRef = _requests.doc(request.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(requestRef);
      final data = snap.data();
      if (data == null ||
          ChangeRequestStatus.parse(data['status']) !=
              ChangeRequestStatus.rejected) {
        throw const ChangeRequestNotRejected();
      }
      tx.update(requestRef, {
        'status': ChangeRequestStatus.pending.wire,
        'decidedBy': FieldValue.delete(),
        'decidedAt': FieldValue.delete(),
      });
    });
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/change_request_repository_test.dart`
Expected: PASS, all tests in the file.

- [ ] **Step 5: Write the failing UI test**

Add to `test/features/change_requests_screen_test.dart`, after the
`'a decided request offers no accept/reject/edit actions'` test:

```dart
  testWidgets('a rejected request offers a restore action, not accept/reject',
      (tester) async {
    final db = await seed();
    await db.collection('change_requests').doc(requestId).update({
      'status': 'rejected',
      'decidedBy': 'a1',
    });
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(const Key('filter-rejected')));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('request-$requestId')), findsOneWidget);
    expect(find.byKey(Key('restore-$requestId')), findsOneWidget);
    expect(find.byKey(Key('accept-$requestId')), findsNothing);
    expect(find.byKey(Key('reject-$requestId')), findsNothing);
  });

  testWidgets('restoring a rejected request returns it to the pending tab',
      (tester) async {
    final db = await seed();
    await db.collection('change_requests').doc(requestId).update({
      'status': 'rejected',
      'decidedBy': 'a1',
    });
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(const Key('filter-rejected')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('restore-$requestId')));
    await tester.pumpAndSettle();

    final request =
        (await db.collection('change_requests').doc(requestId).get()).data()!;
    expect(request['status'], 'pending');
    expect(request.containsKey('decidedBy'), isFalse);

    expect(find.byKey(Key('request-$requestId')), findsNothing);
    await tester.tap(find.byKey(const Key('filter-pending')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('request-$requestId')), findsOneWidget);
  });
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `flutter test test/features/change_requests_screen_test.dart`
Expected: FAIL — `restore-$requestId` does not exist yet.

- [ ] **Step 7: Add the restore action to the UI**

In `lib/features/requests/change_requests_screen.dart`, `_RequestCard` needs
a new callback. Change the constructor:

```dart
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
    required this.onEdit,
  });

  final ChangeRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onEdit;
```

to:

```dart
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
    required this.onEdit,
    required this.onRestore,
  });

  final ChangeRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onEdit;
  final VoidCallback onRestore;
```

Then, still in `_RequestCard.build()`, find the block:

```dart
                  if (request.isPending) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          key: Key('accept-${request.id}'),
                          onPressed: onAccept,
                          child: const Text('Zaakceptuj'),
                        ),
                        TextButton(
                          key: Key('reject-${request.id}'),
                          onPressed: onReject,
                          child: const Text('Odrzuć'),
                        ),
                        TextButton(
                          key: Key('edit-${request.id}'),
                          onPressed: onEdit,
                          child: const Text('Edytuj'),
                        ),
                      ],
                    ),
                  ],
```

and add a sibling block right after its closing `],` (still inside the
`Column`'s `children`, still before the final `],` of that children list):

```dart
                  if (request.status == ChangeRequestStatus.rejected) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          key: Key('restore-${request.id}'),
                          onPressed: onRestore,
                          child: const Text('Przywróć'),
                        ),
                      ],
                    ),
                  ],
```

Now wire the callback where `_RequestCard` is constructed, in
`_ChangeRequestsScreenState.build()`. Find:

```dart
                                child: _RequestCard(
                                  request: request,
                                  onAccept: () => _decide(
                                    () => ref
                                        .read(changeRequestRepositoryProvider)
                                        .accept(request, adminUid: adminUid),
                                    'Prośba zaakceptowana',
                                  ),
                                  onReject: () =>
                                      _confirmAndReject(request, adminUid),
                                  onEdit: () =>
                                      _editThenAccept(request, adminUid),
                                ),
```

and add, right after `onEdit`:

```dart
                                  onEdit: () =>
                                      _editThenAccept(request, adminUid),
                                  onRestore: () => _decide(
                                    () => ref
                                        .read(changeRequestRepositoryProvider)
                                        .restoreToPending(request),
                                    'Prośba przywrócona do oczekujących',
                                  ),
                                ),
```

(i.e. add the `onRestore:` argument to the existing `_RequestCard(...)` call
— do not duplicate `onEdit`.)

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/features/change_requests_screen_test.dart test/data/change_request_repository_test.dart`
Expected: PASS, all tests in both files.

- [ ] **Step 9: Commit**

```bash
git add lib/data/change_request_repository.dart lib/features/requests/change_requests_screen.dart test/data/change_request_repository_test.dart test/features/change_requests_screen_test.dart
git commit -m "feat: let admins restore a rejected request to pending"
```

---

### Task 4: Require the reason field on new requests

**Files:**
- Modify: `lib/features/requests/change_request_form.dart`
- Modify: `lib/features/requests/new_change_request_screen.dart`
- Test: `test/features/change_request_form_test.dart`
- Test: `test/features/new_change_request_screen_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: no new public API — `ChangeRequestForm`'s reason field now
  validates non-empty when `showReason: true` (unchanged when `false`), and
  `NewChangeRequestScreen`'s submit button additionally requires a non-null
  `_reason`.

- [ ] **Step 1: Write the failing form test**

Add to `test/features/change_request_form_test.dart`, after the
`'shows the Polish validation message for non-numeric input'` test:

```dart
  testWidgets('shows a validation message when reason is left empty',
      (tester) async {
    await pumpForm(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('field-reason')), 'x');
    await tester.enterText(find.byKey(const Key('field-reason')), '');
    await tester.pump();

    expect(find.text('Podaj powód'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/change_request_form_test.dart`
Expected: FAIL — `'Podaj powód'` is never shown.

- [ ] **Step 3: Add the validator**

In `lib/features/requests/change_request_form.dart`, find:

```dart
          if (widget.showReason) ...[
            const SizedBox(height: 12),
            _Labelled(
              label: 'Powód',
              child: TextFormField(
                key: const Key('field-reason'),
                controller: _reasonController,
                maxLines: 2,
              ),
            ),
          ],
```

Replace with:

```dart
          if (widget.showReason) ...[
            const SizedBox(height: 12),
            _Labelled(
              label: 'Powód',
              child: TextFormField(
                key: const Key('field-reason'),
                controller: _reasonController,
                maxLines: 2,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Podaj powód' : null,
              ),
            ),
          ],
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/change_request_form_test.dart`
Expected: PASS, all tests in the file.

- [ ] **Step 5: Write the failing screen test**

In `test/features/new_change_request_screen_test.dart`, replace the
`'submit is disabled until something is entered'` test with:

```dart
  testWidgets(
      'submit stays disabled until both a change and a reason are entered',
      (tester) async {
    await pumpScreen(tester, await seed());

    ElevatedButton button() => tester
        .widget<ElevatedButton>(find.byKey(const Key('submit-request')));
    expect(button().onPressed, isNull);

    await tester.enterText(find.byKey(const Key('field-current_xp')), '50');
    await tester.pump();
    expect(button().onPressed, isNull, reason: 'reason is still required');

    await tester.enterText(
        find.byKey(const Key('field-reason')), 'Posprzątałem garaż');
    await tester.pump();

    expect(button().onPressed, isNotNull);
  });
```

- [ ] **Step 6: Run test to verify it fails**

Run: `flutter test test/features/new_change_request_screen_test.dart`
Expected: FAIL on the last `expect` becoming true too early is not the
failure mode here — instead the *middle* `expect(button().onPressed, isNull, ...)`
fails, because today's `canSubmit` does not check `_reason` at all.

- [ ] **Step 7: Gate submit on a non-null reason**

In `lib/features/requests/new_change_request_screen.dart`, find:

```dart
    final canSubmit =
        !_submitting && selected != null && user != null && !_changes.isEmpty;
```

Replace with:

```dart
    final canSubmit = !_submitting &&
        selected != null &&
        user != null &&
        !_changes.isEmpty &&
        _reason != null;
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/features/new_change_request_screen_test.dart test/features/change_request_form_test.dart`
Expected: PASS, all tests in both files.

- [ ] **Step 9: Commit**

```bash
git add lib/features/requests/change_request_form.dart lib/features/requests/new_change_request_screen.dart test/features/change_request_form_test.dart test/features/new_change_request_screen_test.dart
git commit -m "feat: require a reason when submitting a change request"
```

---

### Task 5: Let a requester cancel their own pending request

**Files:**
- Modify: `firestore.rules`
- Modify: `tools/rules-test/rules.test.mjs`
- Modify: `lib/models/change_request.dart`
- Modify: `lib/data/change_request_repository.dart`
- Modify: `lib/features/requests/new_change_request_screen.dart`
- Test: `test/data/change_request_repository_test.dart`
- Test: `test/features/new_change_request_screen_test.dart`

**Interfaces:**
- Consumes: `showConfirmDialog` from `lib/theme/dialogs.dart` (Task 2) — signature `Future<bool> showConfirmDialog(BuildContext context, {required String title, required String cancelLabel, required String confirmLabel, required Key confirmKey})`.
- Produces: `ChangeRequestStatus.cancelled` (new enum value); `ChangeRequestRepository.cancel(ChangeRequest request)`.

- [ ] **Step 1: Write the failing rules tests**

Add to `tools/rules-test/rules.test.mjs`, at the end of the file (after the
`'a non-admin may not decide a request, even their own'` test, still inside
`main`'s top-level scope — this file has no `main()` wrapper, tests are
top-level `test(...)` calls):

```js
test('a user may cancel their own pending request', async () => {
  await seedRequest('req-cancel-mine', ALICE.uid);
  const db = ctxFor(ALICE);
  await assertSucceeds(
    updateDoc(doc(db, 'change_requests/req-cancel-mine'), {
      status: 'cancelled',
    })
  );
});

test("a user may not cancel somebody else's request", async () => {
  await seedRequest('req-cancel-other', BOB.uid);
  const db = ctxFor(ALICE);
  await assertFails(
    updateDoc(doc(db, 'change_requests/req-cancel-other'), {
      status: 'cancelled',
    })
  );
});

test('cancelling may not smuggle in other field changes', async () => {
  await seedRequest('req-cancel-smuggle', ALICE.uid);
  const db = ctxFor(ALICE);
  await assertFails(
    updateDoc(doc(db, 'change_requests/req-cancel-smuggle'), {
      status: 'cancelled',
      decidedBy: ALICE.uid,
    })
  );
});

test('a user may not cancel a request that is no longer pending', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'change_requests/req-cancel-decided'), {
      characterId: 'c-alice',
      characterName: 'Alicja',
      requesterUid: ALICE.uid,
      requesterEmail: ALICE.email,
      status: 'rejected',
      changes: { current_xp: 50 },
    });
  });
  const db = ctxFor(ALICE);
  await assertFails(
    updateDoc(doc(db, 'change_requests/req-cancel-decided'), {
      status: 'cancelled',
    })
  );
});
```

- [ ] **Step 2: Run rules tests to verify they fail**

From the repository root (install once if `tools/rules-test/node_modules` is
missing: `npm --prefix tools/rules-test ci --legacy-peer-deps`):

Run: `npx --yes firebase-tools emulators:exec --only firestore --project liferpg-rules-test "npm --prefix tools/rules-test test"`
Expected: FAIL — the first new test (`'a user may cancel their own pending request'`) fails because the current rule only allows `update`/`delete` for admins.

- [ ] **Step 3: Update the security rule**

In `firestore.rules`, find:

```
      // Accepting also writes /characters/{id}, which is already admin-only,
      // so the whole apply path runs as an admin.
      allow update, delete: if isAdmin();
```

Replace with:

```
      // Accepting also writes /characters/{id}, which is already admin-only,
      // so the whole apply path runs as an admin. The one non-admin path is
      // a requester withdrawing their own still-pending request: that may
      // only flip status to 'cancelled' and touch no other field.
      allow update: if isAdmin()
                    || (isAuthenticated()
                        && resource.data.requesterUid == request.auth.uid
                        && resource.data.status == 'pending'
                        && request.resource.data.status == 'cancelled'
                        && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status']));
      allow delete: if isAdmin();
```

- [ ] **Step 4: Run rules tests to verify they pass**

Run: `npx --yes firebase-tools emulators:exec --only firestore --project liferpg-rules-test "npm --prefix tools/rules-test test"`
Expected: PASS, every test in `rules.test.mjs` (the whole suite, not just the new tests — this rule change must not break any earlier test).

- [ ] **Step 5: Write the failing repository test**

Add to `test/data/change_request_repository_test.dart`, after the
`restoreToPending` tests added in Task 3:

```dart
  test('cancel marks a pending request cancelled', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db);
    await repo.create(_request(characterId: characterId));

    await repo.cancel(await onlyRequest(db));

    final cancelled = await onlyRequest(db);
    expect(cancelled.status, ChangeRequestStatus.cancelled);
  });

  test('cancel throws if the request is already decided', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db);
    await repo.create(_request(characterId: characterId));
    await repo.reject(await onlyRequest(db), adminUid: 'admin1');

    await expectLater(
      repo.cancel(await onlyRequest(db)),
      throwsA(isA<ChangeRequestNoLongerPending>()),
    );
  });
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `flutter test test/data/change_request_repository_test.dart`
Expected: FAIL — `ChangeRequestStatus.cancelled` and `repo.cancel` do not exist (compile error).

- [ ] **Step 7: Add the `cancelled` status and the `cancel` method**

In `lib/models/change_request.dart`, find:

```dart
enum ChangeRequestStatus {
  pending,
  accepted,
  rejected;
```

Replace with:

```dart
enum ChangeRequestStatus {
  pending,
  accepted,
  rejected,
  cancelled;
```

In `lib/data/change_request_repository.dart`, add this method right after
`reject`:

```dart
  /// The requester's own withdrawal of a request they no longer want acted
  /// on. Reuses the pending guard from accept/reject: a request that has
  /// already been decided (or already cancelled) throws
  /// [ChangeRequestNoLongerPending], same as a double-tap on accept/reject.
  Future<void> cancel(ChangeRequest request) async {
    final requestRef = _requests.doc(request.id);
    await _db.runTransaction((tx) async {
      await _readPending(tx, requestRef);
      tx.update(requestRef, {'status': ChangeRequestStatus.cancelled.wire});
    });
  }
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/data/change_request_repository_test.dart`
Expected: PASS, all tests in the file.

- [ ] **Step 9: Write the failing UI test**

Add to `test/features/new_change_request_screen_test.dart`:

```dart
  testWidgets('a pending request can be cancelled with confirmation',
      (tester) async {
    final db = await seed();
    final request = await db.collection('change_requests').add({
      'characterId': 'whatever',
      'characterName': 'Bohater 0',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'pending',
      'changes': {'current_xp': 50},
    });
    await pumpScreen(tester, db);

    expect(find.byKey(Key('cancel-request-${request.id}')), findsOneWidget);
    await tester.tap(find.byKey(Key('cancel-request-${request.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('confirm-cancel-${request.id}')));
    await tester.pumpAndSettle();

    final data =
        (await db.collection('change_requests').doc(request.id).get())
            .data()!;
    expect(data['status'], 'cancelled');
    expect(find.text('Anulowana'), findsOneWidget);
  });

  testWidgets('backing out of the cancel confirmation changes nothing',
      (tester) async {
    final db = await seed();
    final request = await db.collection('change_requests').add({
      'characterId': 'whatever',
      'characterName': 'Bohater 0',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'pending',
      'changes': {'current_xp': 50},
    });
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(Key('cancel-request-${request.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NIE'));
    await tester.pumpAndSettle();

    final data =
        (await db.collection('change_requests').doc(request.id).get())
            .data()!;
    expect(data['status'], 'pending');
  });
```

- [ ] **Step 10: Run tests to verify they fail**

Run: `flutter test test/features/new_change_request_screen_test.dart`
Expected: FAIL — `cancel-request-*` does not exist yet.

- [ ] **Step 11: Add the cancel UI**

In `lib/features/requests/new_change_request_screen.dart`, add the import:

```dart
import '../../theme/dialogs.dart';
```

Add this method to `_NewChangeRequestScreenState`, right after `_submit`:

```dart
  Future<void> _cancel(ChangeRequest request) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Anulować prośbę?',
      cancelLabel: 'Nie',
      confirmLabel: 'Tak, anuluj',
      confirmKey: Key('confirm-cancel-${request.id}'),
    );
    if (!confirmed) return;
    try {
      await ref.read(changeRequestRepositoryProvider).cancel(request);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }
```

Then find, in `build()`:

```dart
                for (final r in myRequests)
                  Padding(
                    key: Key('my-request-${r.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(r.characterName,
                            style: const TextStyle(color: parchmentMuted)),
                        Text(
                          switch (r.status) {
                            ChangeRequestStatus.pending => 'Oczekuje',
                            ChangeRequestStatus.accepted => 'Zaakceptowana',
                            ChangeRequestStatus.rejected => 'Odrzucona',
                          },
                          style: const TextStyle(
                            fontFamily: fontDisplay,
                            fontSize: 9,
                            letterSpacing: 2,
                            color: parchmentFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
```

Replace with:

```dart
                for (final r in myRequests)
                  Padding(
                    key: Key('my-request-${r.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(r.characterName,
                              style: const TextStyle(color: parchmentMuted)),
                        ),
                        Text(
                          switch (r.status) {
                            ChangeRequestStatus.pending => 'Oczekuje',
                            ChangeRequestStatus.accepted => 'Zaakceptowana',
                            ChangeRequestStatus.rejected => 'Odrzucona',
                            ChangeRequestStatus.cancelled => 'Anulowana',
                          },
                          style: const TextStyle(
                            fontFamily: fontDisplay,
                            fontSize: 9,
                            letterSpacing: 2,
                            color: parchmentFaint,
                          ),
                        ),
                        if (r.status == ChangeRequestStatus.pending)
                          IconButton(
                            key: Key('cancel-request-${r.id}'),
                            tooltip: 'Anuluj',
                            icon: const Icon(Icons.close,
                                size: 16, color: crimson),
                            onPressed: () => _cancel(r),
                          ),
                      ],
                    ),
                  ),
```

- [ ] **Step 12: Run tests to verify they pass**

Run: `flutter test test/features/new_change_request_screen_test.dart`
Expected: PASS, all tests in the file.

- [ ] **Step 13: Run the full Flutter suite and the rules suite once more**

Run: `flutter test`
Expected: PASS, no regressions anywhere. (The `switch (r.status)` in
`NewChangeRequestScreen`, updated in Step 11, is the only exhaustive switch
over `ChangeRequestStatus` in the codebase — every other reference is either
`.wire`/`.parse`, an equality check against `.pending`, or an individual
`ChangeRequestStatus.pending`/`.accepted`/`.rejected` value, none of which
need a `cancelled` case.)

Run: `npx --yes firebase-tools emulators:exec --only firestore --project liferpg-rules-test "npm --prefix tools/rules-test test"`
Expected: PASS, no regressions.

- [ ] **Step 14: Commit**

```bash
git add firestore.rules tools/rules-test/rules.test.mjs lib/models/change_request.dart lib/data/change_request_repository.dart lib/features/requests/new_change_request_screen.dart test/data/change_request_repository_test.dart test/features/new_change_request_screen_test.dart
git commit -m "feat: let a requester cancel their own pending change request"
```

---

### Task 6: Remove the dollars (gold_usd) field entirely

**Files:**
- Modify: `lib/models/character.dart`
- Modify: `lib/models/change_request.dart`
- Modify: `lib/features/character/character_card.dart`
- Modify: `lib/features/character/edit_character_screen.dart`
- Modify: `lib/features/requests/change_request_form.dart`
- Modify: `lib/features/requests/change_requests_screen.dart`
- Modify: `lib/data/change_request_repository.dart`
- Modify: `CLAUDE.md`
- Test: `test/models/character_test.dart`
- Test: `test/features/character_card_test.dart`
- Test: `test/features/edit_character_screen_test.dart`
- Test: `test/models/change_request_test.dart`
- Test: `test/features/change_request_form_test.dart`
- Test: `test/data/change_request_repository_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `Character.goldUsd`, `ChangeSet.goldUsd`, and the Firestore field
  `gold_usd` no longer exist anywhere in the codebase after this task. No
  later task in this plan depends on them.

This is a mechanical, compile-driven removal: delete the field from
production code first, then follow the compiler errors into the tests. Do
not use TDD-style "write a failing test first" here — there is no new
behavior to specify, only old behavior to delete, and the compiler is a more
precise failing-test signal than a hand-written one would be.

- [ ] **Step 1: Remove `goldUsd` from the `Character` model**

In `lib/models/character.dart`:

Find the constructor:

```dart
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
```

Replace with:

```dart
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
```

Find, in `Character.fromMap`:

```dart
      gold: _asNum(data['gold']),
      goldUsd: _asNum(data['gold_usd']),
      favour: _asInt(data['favour']) ?? 0,
```

Replace with:

```dart
      gold: _asNum(data['gold']),
      favour: _asInt(data['favour']) ?? 0,
```

Find, in `toMap`:

```dart
        'gold': gold,
        'gold_usd': goldUsd,
        'favour': favour,
```

Replace with:

```dart
        'gold': gold,
        'favour': favour,
```

Find, in `copyWith`:

```dart
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
```

Replace with:

```dart
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
```

- [ ] **Step 2: Remove `goldUsd` from the `ChangeSet` model**

In `lib/models/change_request.dart`, find:

```dart
class ChangeSet {
  const ChangeSet({
    this.currentXp,
    this.gold,
    this.goldUsd,
    this.traits = const [],
  });

  final num? currentXp;
  final num? gold;
  final num? goldUsd;
  final List<TraitChange> traits;

  bool get isEmpty =>
      currentXp == null && gold == null && goldUsd == null && traits.isEmpty;

  factory ChangeSet.fromMap(Map<String, dynamic> data) {
    final rawTraits = data['traits'];
    return ChangeSet(
      currentXp: _asNum(data['current_xp']),
      gold: _asNum(data['gold']),
      goldUsd: _asNum(data['gold_usd']),
      traits: rawTraits is List
          ? rawTraits
              .whereType<Map>()
              .map((t) => TraitChange.fromMap(Map<String, dynamic>.from(t)))
              .toList()
          : const <TraitChange>[],
    );
  }

  Map<String, dynamic> toMap() => {
        if (currentXp != null) 'current_xp': currentXp,
        if (gold != null) 'gold': gold,
        if (goldUsd != null) 'gold_usd': goldUsd,
        if (traits.isNotEmpty)
          'traits': traits.map((t) => t.toMap()).toList(),
      };
}
```

Replace with:

```dart
class ChangeSet {
  const ChangeSet({
    this.currentXp,
    this.gold,
    this.traits = const [],
  });

  final num? currentXp;
  final num? gold;
  final List<TraitChange> traits;

  bool get isEmpty =>
      currentXp == null && gold == null && traits.isEmpty;

  factory ChangeSet.fromMap(Map<String, dynamic> data) {
    final rawTraits = data['traits'];
    return ChangeSet(
      currentXp: _asNum(data['current_xp']),
      gold: _asNum(data['gold']),
      traits: rawTraits is List
          ? rawTraits
              .whereType<Map>()
              .map((t) => TraitChange.fromMap(Map<String, dynamic>.from(t)))
              .toList()
          : const <TraitChange>[],
    );
  }

  Map<String, dynamic> toMap() => {
        if (currentXp != null) 'current_xp': currentXp,
        if (gold != null) 'gold': gold,
        if (traits.isNotEmpty)
          'traits': traits.map((t) => t.toMap()).toList(),
      };
}
```

- [ ] **Step 3: Remove the currency chip from `CharacterCard`**

In `lib/features/character/character_card.dart`, find:

```dart
          Row(
            children: [
              Text('${character.gold} zł', style: _goldValue),
              if (character.goldUsd != null) ...[
                const Text(' · ', style: TextStyle(color: crimson)),
                Text('${character.goldUsd} \$', style: _goldValue),
              ],
            ],
          ),
```

Replace with:

```dart
          Row(
            children: [
              Text('${character.gold} zł', style: _goldValue),
            ],
          ),
```

- [ ] **Step 4: Remove the field from `EditCharacterScreen`**

In `lib/features/character/edit_character_screen.dart`, find:

```dart
// `level`, `current_xp` and `next_level_xp` are ints in Firestore; `gold` and
// `gold_usd` are `num` and legitimately hold decimals in production documents
// (the React editor wrote `Number(e.target.value)`), so those two must accept
// "12.5" rather than rejecting the character outright.
```

Replace with:

```dart
// `level`, `current_xp` and `next_level_xp` are ints in Firestore; `gold` is
// `num` and legitimately holds decimals in production documents (the React
// editor wrote `Number(e.target.value)`), so it must accept "12.5" rather
// than rejecting the character outright.
```

Find:

```dart
    _controllers = {
      'level': TextEditingController(text: c.level?.toString() ?? ''),
      'gold': TextEditingController(text: c.gold?.toString() ?? ''),
      'gold_usd': TextEditingController(text: c.goldUsd?.toString() ?? ''),
      'current_xp': TextEditingController(text: c.currentXp.toString()),
      'next_level_xp': TextEditingController(text: c.nextLevelXp.toString()),
    };
```

Replace with:

```dart
    _controllers = {
      'level': TextEditingController(text: c.level?.toString() ?? ''),
      'gold': TextEditingController(text: c.gold?.toString() ?? ''),
      'current_xp': TextEditingController(text: c.currentXp.toString()),
      'next_level_xp': TextEditingController(text: c.nextLevelXp.toString()),
    };
```

Find:

```dart
  // Nullable fields (`level`, `gold`, `gold_usd`): an empty box is ambiguous,
  // and the character's original value disambiguates it. If the field was
  // already absent, we return null — copyWith reads that as "leave unchanged"
  // and the field stays absent, so a save that never touched gold no longer
  // invents a `gold: 0` row on the card. If the field did hold a value, the
  // empty box is a deliberate clear and we write 0.
```

Replace with:

```dart
  // Nullable fields (`level`, `gold`): an empty box is ambiguous, and the
  // character's original value disambiguates it. If the field was already
  // absent, we return null — copyWith reads that as "leave unchanged" and the
  // field stays absent, so a save that never touched gold no longer invents a
  // `gold: 0` row on the card. If the field did hold a value, the empty box is
  // a deliberate clear and we write 0.
```

Find, in `_save`:

```dart
      final updated = original.copyWith(
        level: _nullableIntOf('level', original.level),
        gold: _nullableNumOf('gold', original.gold),
        goldUsd: _nullableNumOf('gold_usd', original.goldUsd),
        currentXp: _intOf('current_xp'),
        nextLevelXp: _intOf('next_level_xp'),
        favour: _favour,
        traits: _traits,
      );
```

Replace with:

```dart
      final updated = original.copyWith(
        level: _nullableIntOf('level', original.level),
        gold: _nullableNumOf('gold', original.gold),
        currentXp: _intOf('current_xp'),
        nextLevelXp: _intOf('next_level_xp'),
        favour: _favour,
        traits: _traits,
      );
```

Find:

```dart
                                _LabelledField(
                                  label: 'Złoto',
                                  child:
                                      _numberField('gold', _controllers['gold']!,
                                          decimal: true),
                                ),
                                _LabelledField(
                                  label: 'Dolary',
                                  child: _numberField(
                                      'gold_usd', _controllers['gold_usd']!,
                                      decimal: true),
                                ),
                                Row(
```

Replace with:

```dart
                                _LabelledField(
                                  label: 'Złoto',
                                  child:
                                      _numberField('gold', _controllers['gold']!,
                                          decimal: true),
                                ),
                                Row(
```

- [ ] **Step 5: Remove the field from `ChangeRequestForm`**

In `lib/features/requests/change_request_form.dart`, find:

```dart
    _controllers = {
      'current_xp': TextEditingController(
        text: initial?.currentXp?.toString() ?? '',
      ),
      'gold': TextEditingController(text: initial?.gold?.toString() ?? ''),
      'gold_usd': TextEditingController(
        text: initial?.goldUsd?.toString() ?? '',
      ),
    };
```

Replace with:

```dart
    _controllers = {
      'current_xp': TextEditingController(
        text: initial?.currentXp?.toString() ?? '',
      ),
      'gold': TextEditingController(text: initial?.gold?.toString() ?? ''),
    };
```

Find:

```dart
  ChangeSet get _changes => ChangeSet(
    currentXp: _deltaOf('current_xp', decimal: false),
    gold: _deltaOf('gold', decimal: true),
    goldUsd: _deltaOf('gold_usd', decimal: true),
    traits: _traits,
  );
```

Replace with:

```dart
  ChangeSet get _changes => ChangeSet(
    currentXp: _deltaOf('current_xp', decimal: false),
    gold: _deltaOf('gold', decimal: true),
    traits: _traits,
  );
```

Find:

```dart
          _Labelled(label: 'Złoto', child: _deltaField('gold', decimal: true)),
          _Labelled(
            label: 'Dolary',
            child: _deltaField('gold_usd', decimal: true),
          ),
          const SizedBox(height: 12),
```

Replace with:

```dart
          _Labelled(label: 'Złoto', child: _deltaField('gold', decimal: true)),
          const SizedBox(height: 12),
```

- [ ] **Step 6: Remove the field from the admin queue's delta display**

In `lib/features/requests/change_requests_screen.dart`, find:

```dart
    final deltaLines = <String>[
      if (changes.currentXp != null) 'XP: ${_signed(changes.currentXp!)}',
      if (changes.gold != null) 'Złoto: ${_signed(changes.gold!)}',
      if (changes.goldUsd != null) 'Dolary: ${_signed(changes.goldUsd!)}',
    ];
```

Replace with:

```dart
    final deltaLines = <String>[
      if (changes.currentXp != null) 'XP: ${_signed(changes.currentXp!)}',
      if (changes.gold != null) 'Złoto: ${_signed(changes.gold!)}',
    ];
```

- [ ] **Step 7: Remove the field from delta application**

In `lib/data/change_request_repository.dart`, find:

```dart
    final updates = <String, dynamic>{
      if (changes.currentXp != null)
        'current_xp': (current('current_xp') + changes.currentXp!).toInt(),
      if (changes.gold != null) 'gold': current('gold') + changes.gold!,
      if (changes.goldUsd != null)
        'gold_usd': current('gold_usd') + changes.goldUsd!,
    };
```

Replace with:

```dart
    final updates = <String, dynamic>{
      if (changes.currentXp != null)
        'current_xp': (current('current_xp') + changes.currentXp!).toInt(),
      if (changes.gold != null) 'gold': current('gold') + changes.gold!,
    };
```

- [ ] **Step 8: Update CLAUDE.md**

In `CLAUDE.md`, find:

```
name, clazz, email, level, current_xp, next_level_xp, gold, gold_usd, favour
```

Replace with:

```
name, clazz, email, level, current_xp, next_level_xp, gold, favour
```

Find:

```
changes:        { current_xp?, gold?, gold_usd?, traits?: [{name, value}] }
```

Replace with:

```
changes:        { current_xp?, gold?, traits?: [{name, value}] }
```

Find:

```
- Applying a delta `.toInt()`s the resulting `current_xp` (XP is always
  whole), while `gold` and `gold_usd` stay `num` so a fractional delta is
  preserved. A non-numeric legacy value on the character (e.g. a stringly
```

Replace with:

```
- Applying a delta `.toInt()`s the resulting `current_xp` (XP is always
  whole), while `gold` stays `num` so a fractional delta is preserved. A
  non-numeric legacy value on the character (e.g. a stringly
```

Find:

```
- **Currency**: `gold` = PLN (złoty), `gold_usd` = USD. Both displayed as chips if present.
```

Replace with:

```
- **Currency**: `gold` = PLN (złoty), displayed as a chip if present.
```

Find:

```
- Firestore field names stay snake_case (`current_xp`, `next_level_xp`,
  `gold_usd`); Dart-side names are camelCase and mapped in the models.
```

Replace with:

```
- Firestore field names stay snake_case (`current_xp`, `next_level_xp`);
  Dart-side names are camelCase and mapped in the models.
```

- [ ] **Step 9: Run the full test suite and follow the compile errors**

Run: `flutter test`
Expected: a batch of compile errors in the test files listed below, each
naming a `goldUsd`/`gold_usd` reference that no longer exists. Fix each as
described in the following steps, then re-run.

- [ ] **Step 10: Fix `test/models/character_test.dart`**

Find:

```dart
Map<String, dynamic> raw() => {
      'name': 'Grommash',
      'clazz': 'Wojownik',
      'email': 'g@example.com',
      'level': 3,
      'current_xp': 40,
      'next_level_xp': 100,
      'gold': 250,
      'gold_usd': 12,
      'favour': -2,
      'traits': [
        {'name': 'Siła', 'value': '18'},
      ],
    };
```

Replace with:

```dart
Map<String, dynamic> raw() => {
      'name': 'Grommash',
      'clazz': 'Wojownik',
      'email': 'g@example.com',
      'level': 3,
      'current_xp': 40,
      'next_level_xp': 100,
      'gold': 250,
      'favour': -2,
      'traits': [
        {'name': 'Siła', 'value': '18'},
      ],
    };
```

Find:

```dart
    expect(c.currentXp, 40);
    expect(c.nextLevelXp, 100);
    expect(c.goldUsd, 12);
    expect(c.favour, -2);
```

Replace with:

```dart
    expect(c.currentXp, 40);
    expect(c.nextLevelXp, 100);
    expect(c.favour, -2);
```

Find and delete this whole test:

```dart
  test('gold_usd stored as the String "12.5" parses to 12.5', () {
    final c = Character.fromMap('abc', {...raw(), 'gold_usd': '12.5'});
    expect(c.goldUsd, 12.5);
  });

```

(Delete the whole block including its trailing blank line, so the two tests
before and after it are separated by exactly one blank line, same as
elsewhere in the file.)

- [ ] **Step 11: Fix `test/features/character_card_test.dart`**

Find:

```dart
Character sample({List<Trait> traits = const []}) => Character(
      id: 'c1',
      name: 'Grommash',
      clazz: 'Wojownik',
      email: 'g@example.com',
      level: 3,
      currentXp: 40,
      nextLevelXp: 100,
      gold: 250,
      goldUsd: 12,
      favour: 0,
      traits: traits,
    );
```

Replace with:

```dart
Character sample({List<Trait> traits = const []}) => Character(
      id: 'c1',
      name: 'Grommash',
      clazz: 'Wojownik',
      email: 'g@example.com',
      level: 3,
      currentXp: 40,
      nextLevelXp: 100,
      gold: 250,
      favour: 0,
      traits: traits,
    );
```

Find:

```dart
  testWidgets('renders name, class, level, XP and gold in both currencies',
      (tester) async {
    await tester.pumpWidget(
      wrap(CharacterCard(character: sample(), canEdit: false)),
    );

    expect(find.text('Grommash'), findsOneWidget);
    expect(find.text('WOJOWNIK'), findsOneWidget);
    expect(find.text('POZIOM'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('250 zł'), findsOneWidget);
    expect(find.text('12 \$'), findsOneWidget);
    expect(find.text('40 / 100 XP'), findsOneWidget);
  });
```

Replace with:

```dart
  testWidgets('renders name, class, level, XP and gold',
      (tester) async {
    await tester.pumpWidget(
      wrap(CharacterCard(character: sample(), canEdit: false)),
    );

    expect(find.text('Grommash'), findsOneWidget);
    expect(find.text('WOJOWNIK'), findsOneWidget);
    expect(find.text('POZIOM'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('250 zł'), findsOneWidget);
    expect(find.text('40 / 100 XP'), findsOneWidget);
  });
```

Find, in the XP-track-width regression test:

```dart
    final partial = Character(
      id: 'c1',
      name: 'Grommash',
      clazz: 'Wojownik',
      email: 'g@example.com',
      level: 3,
      currentXp: 915,
      nextLevelXp: 2500,
      gold: 250,
      goldUsd: 12,
      favour: 0,
      traits: const [],
    );
```

Replace with:

```dart
    final partial = Character(
      id: 'c1',
      name: 'Grommash',
      clazz: 'Wojownik',
      email: 'g@example.com',
      level: 3,
      currentXp: 915,
      nextLevelXp: 2500,
      gold: 250,
      favour: 0,
      traits: const [],
    );
```

- [ ] **Step 12: Fix `test/features/edit_character_screen_test.dart`**

Find:

```dart
Future<(FakeFirebaseFirestore, Character)> seed({
  num goldUsd = 12,
  bool withGold = true,
}) async {
  final db = FakeFirebaseFirestore();
  final ref = await db.collection('characters').add({
    'name': 'Grommash',
    'email': 'g@example.com',
    'level': 3,
    'current_xp': 40,
    'next_level_xp': 100,
    if (withGold) 'gold': 250,
    if (withGold) 'gold_usd': goldUsd,
    'favour': 0,
    'traits': [
      {'name': 'Siła', 'value': '18'},
    ],
  });
  final snap = await ref.get();
  return (db, Character.fromMap(ref.id, snap.data()!));
}
```

Replace with:

```dart
Future<(FakeFirebaseFirestore, Character)> seed({
  bool withGold = true,
}) async {
  final db = FakeFirebaseFirestore();
  final ref = await db.collection('characters').add({
    'name': 'Grommash',
    'email': 'g@example.com',
    'level': 3,
    'current_xp': 40,
    'next_level_xp': 100,
    if (withGold) 'gold': 250,
    'favour': 0,
    'traits': [
      {'name': 'Siła', 'value': '18'},
    ],
  });
  final snap = await ref.get();
  return (db, Character.fromMap(ref.id, snap.data()!));
}
```

Find and delete this whole test (including the comment above it and the
trailing blank line, so surrounding tests keep single-blank-line spacing):

```dart
  // I2: gold/gold_usd are `num`, not `int`. Before the fix, int.tryParse
  // rejected "12.5" and every save was blocked by a validation error on a
  // field the admin never touched.
  testWidgets('a fractional gold_usd loads and survives an unchanged save',
      (tester) async {
    final (db, character) = await seed(goldUsd: 12.5);
    await pumpEdit(tester, db, character);

    expect(find.widgetWithText(TextFormField, '12.5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-character')));
    await tester.pumpAndSettle();

    expect(find.text('Podaj liczbę'), findsNothing);
    final snap = await db.collection('characters').doc(character.id).get();
    expect(snap.data()!['gold_usd'], 12.5);
  });

```

Find:

```dart
    final data = (await db.collection('characters').doc(character.id).get())
        .data()!;
    expect(data['level'], 7, reason: 'the level the admin did edit must land');
    expect(data['gold'], isNull, reason: 'absent gold must not become 0');
    expect(data['gold_usd'], isNull);
  });
```

Replace with:

```dart
    final data = (await db.collection('characters').doc(character.id).get())
        .data()!;
    expect(data['level'], 7, reason: 'the level the admin did edit must land');
    expect(data['gold'], isNull, reason: 'absent gold must not become 0');
  });
```

- [ ] **Step 13: Fix `test/models/change_request_test.dart`**

Find:

```dart
      'changes': {
        'current_xp': 50,
        'gold': -10,
        'gold_usd': 2.5,
        'traits': [
          {'name': 'Siła', 'value': '12'},
        ],
      },
    });
```

Replace with:

```dart
      'changes': {
        'current_xp': 50,
        'gold': -10,
        'traits': [
          {'name': 'Siła', 'value': '12'},
        ],
      },
    });
```

Find:

```dart
    expect(r.changes.currentXp, 50);
    expect(r.changes.gold, -10);
    expect(r.changes.goldUsd, 2.5);
    expect(r.changes.traits.single.name, 'Siła');
```

Replace with:

```dart
    expect(r.changes.currentXp, 50);
    expect(r.changes.gold, -10);
    expect(r.changes.traits.single.name, 'Siła');
```

- [ ] **Step 14: Fix `test/features/change_request_form_test.dart`**

Find:

```dart
    final changes = await latest();
    expect(changes.currentXp, 50);
    expect(changes.gold, -10);
    expect(changes.goldUsd, isNull);
  });
```

Replace with:

```dart
    final changes = await latest();
    expect(changes.currentXp, 50);
    expect(changes.gold, -10);
  });
```

- [ ] **Step 15: Fix `test/data/change_request_repository_test.dart`**

Find:

```dart
  test('a delta against an absent field materialises it from zero', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    // No `gold` and no `gold_usd` key at all on this character.
    final characterId = await seedCharacter(db);
    await repo.create(_request(
      characterId: characterId,
      changes: const ChangeSet(gold: 10, goldUsd: 2.5),
    ));

    await repo.accept(await onlyRequest(db), adminUid: 'admin1');

    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['gold'], 10);
    expect(character['gold_usd'], 2.5);
  });
```

Replace with:

```dart
  test('a delta against an absent field materialises it from zero', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    // No `gold` key at all on this character.
    final characterId = await seedCharacter(db);
    await repo.create(_request(
      characterId: characterId,
      changes: const ChangeSet(gold: 10),
    ));

    await repo.accept(await onlyRequest(db), adminUid: 'admin1');

    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['gold'], 10);
  });
```

- [ ] **Step 16: Run the full suite to verify everything passes**

Run: `flutter test`
Expected: PASS, every test in the suite.

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 17: Commit**

```bash
git add lib/models/character.dart lib/models/change_request.dart lib/features/character/character_card.dart lib/features/character/edit_character_screen.dart lib/features/requests/change_request_form.dart lib/features/requests/change_requests_screen.dart lib/data/change_request_repository.dart CLAUDE.md test/models/character_test.dart test/features/character_card_test.dart test/features/edit_character_screen_test.dart test/models/change_request_test.dart test/features/change_request_form_test.dart test/data/change_request_repository_test.dart
git commit -m "refactor: remove the unused gold_usd (dollars) field"
```
