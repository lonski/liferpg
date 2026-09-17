# Quest Deep Links as Verified Android App Links Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shared quest links become real, tappable `https://liferpg.lonski.pl/quest/<id>` links that open LifeRPG directly on a device that has it installed, instead of the current inert `liferpg://quest/<id>` custom-scheme text that no share target (confirmed: Signal) ever linkifies.

**Architecture:** Add a verified Android App Link (`autoVerify="true"` intent-filter for `https://liferpg.lonski.pl/quest/*`) alongside the existing `liferpg://quest` custom-scheme intent-filter (kept, still used by the web fallback page). Host a small static site — `.well-known/assetlinks.json` plus a JS fallback page — on a new `gh-pages` branch of this repo, served via GitHub Pages at the custom domain. `lib/data/quest_deep_link.dart` changes what URL it builds and accepts both URL shapes when parsing an incoming link, so already-shared old-format links keep working.

**Tech Stack:** Dart/Flutter (`quest_deep_link.dart`, pure functions, `flutter_test`), Android manifest XML, static HTML/CSS/JS (no build step), git (a second `gh-pages` branch via `git worktree`).

**Spec:** `docs/superpowers/specs/2026-09-17-quest-deep-link-app-links-design.md`

## Global Constraints

- UI-facing text in any new HTML lives in **Polish**, matching every other user-facing string in this app (see `CLAUDE.md`'s "UI Language" section) — e.g. "Otwórz w LifeRPG", not "Open in LifeRPG".
- Application id is `com.liferpg.app` (from `android/app/build.gradle.kts:34`) — must match exactly in `assetlinks.json`.
- The two SHA-256 cert fingerprints that must both appear in `assetlinks.json`'s `sha256_cert_fingerprints` array (already extracted via `keytool -list -v` against this machine's release keystore, per `android/key.properties`, and `~/.android/debug.keystore`):
  - release: `21:5D:77:BC:1D:35:8D:72:1E:C5:36:AB:ED:CC:89:AA:FA:67:62:75:7C:7E:1E:0A:4C:36:BF:ED:62:D7:50:E3`
  - debug: `66:87:6C:F7:90:64:F8:E8:AE:C7:2B:55:7D:0D:1D:C9:65:37:12:66:78:A0:6F:A4:29:83:CB:07:93:CC:6B:AA`
- The domain is `liferpg.lonski.pl` — used verbatim in the manifest's `android:host`, in `assetlinks.json` (implicitly, via being the domain it's hosted at), in the `CNAME` file, and in `quest_deep_link.dart`.
- Never push the new `gh-pages` branch to `origin` without the user explicitly confirming first in the conversation (it's a shared-state action — see Task 3, Step 7).
- Don't touch `docs/` on `master` for any of this — it already holds unrelated spec/plan docs (this very file included) and must not become part of the published site.

---

## Task 1: `quest_deep_link.dart` — new URL shape with back-compat parsing

**Files:**
- Modify: `lib/data/quest_deep_link.dart`
- Test: `test/data/quest_deep_link_test.dart`

**Interfaces:**
- Produces: `String questDeepLink(String questId)` (signature unchanged, return value shape changes) and `String? questIdFromDeepLink(Uri uri)` (signature unchanged, now accepts two URI shapes) — both already consumed by `lib/features/quests/quest_share.dart` (`questDeepLink`) and `lib/main.dart` (`questIdFromDeepLink`, inside `_handleUri`, `lib/main.dart:38`). Neither call site changes in this plan.

- [ ] **Step 1: Write the failing tests**

Replace the full contents of `test/data/quest_deep_link_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/quest_deep_link.dart';

void main() {
  test('questDeepLink builds a https://liferpg.lonski.pl/quest/<id> link', () {
    expect(
      questDeepLink('abc123'),
      'https://liferpg.lonski.pl/quest/abc123',
    );
  });

  test('questIdFromDeepLink extracts the id from the https link shape', () {
    expect(
      questIdFromDeepLink(
        Uri.parse('https://liferpg.lonski.pl/quest/abc123'),
      ),
      'abc123',
    );
  });

  test(
      'questIdFromDeepLink still extracts the id from the legacy '
      'liferpg://quest/<id> shape', () {
    expect(questIdFromDeepLink(Uri.parse('liferpg://quest/abc123')), 'abc123');
  });

  test('questIdFromDeepLink rejects an https link on the wrong host', () {
    expect(
      questIdFromDeepLink(Uri.parse('https://example.com/quest/abc123')),
      isNull,
    );
  });

  test('questIdFromDeepLink rejects an http (non-https) link', () {
    expect(
      questIdFromDeepLink(Uri.parse('http://liferpg.lonski.pl/quest/abc123')),
      isNull,
    );
  });

  test(
      'questIdFromDeepLink rejects an https link whose first path segment '
      "isn't quest", () {
    expect(
      questIdFromDeepLink(
        Uri.parse('https://liferpg.lonski.pl/character/abc123'),
      ),
      isNull,
    );
  });

  test('questIdFromDeepLink rejects an https link with no id segment', () {
    expect(
      questIdFromDeepLink(Uri.parse('https://liferpg.lonski.pl/quest/')),
      isNull,
    );
    expect(
      questIdFromDeepLink(Uri.parse('https://liferpg.lonski.pl/quest')),
      isNull,
    );
  });

  test('questIdFromDeepLink rejects the legacy shape on the wrong host', () {
    expect(
      questIdFromDeepLink(Uri.parse('liferpg://character/abc123')),
      isNull,
    );
  });

  test('questIdFromDeepLink rejects the legacy shape with no id segment', () {
    expect(questIdFromDeepLink(Uri.parse('liferpg://quest/')), isNull);
    expect(questIdFromDeepLink(Uri.parse('liferpg://quest')), isNull);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/data/quest_deep_link_test.dart`
Expected: the first three tests (the ones asserting the new `https://liferpg.lonski.pl/...` shape and its parsing) FAIL — `questDeepLink` still returns the old `liferpg://` string, and `questIdFromDeepLink` doesn't recognize the https shape yet. The other tests may already pass against the old implementation; that's fine, they're regression coverage going forward.

- [ ] **Step 3: Implement**

Replace the full contents of `lib/data/quest_deep_link.dart` with:

```dart
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/data/quest_deep_link_test.dart`
Expected: PASS, all 9 tests.

- [ ] **Step 5: Run the full test suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: both clean — this file has two other call sites (`lib/features/quests/quest_share.dart`, `lib/main.dart`) that consume it by signature only, so no other file needs a change, but this confirms it.

- [ ] **Step 6: Commit**

```bash
git add lib/data/quest_deep_link.dart test/data/quest_deep_link_test.dart
git commit -m "$(cat <<'EOF'
feat: switch quest deep links to https://liferpg.lonski.pl

Custom liferpg:// links never render as tappable in share targets
(confirmed: Signal) since only http/https gets auto-linkified. Switches
to a real https link, matching the new verified Android App Link,
while still accepting the old liferpg:// shape so already-shared links
keep working.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Android manifest — verified App Link intent-filter

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml:44-58`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: nothing consumed by other tasks — Android's own App Links verification reads this at install time.

- [ ] **Step 1: Edit the manifest**

In `android/app/src/main/AndroidManifest.xml`, the current block (lines 49-58) reads:

```xml
            <!-- Opens a shared quest's card. No android:autoVerify: this is
                 a plain custom scheme, not a verified Android App Link, so
                 there's no domain/assetlinks.json to host. A link tapped
                 without the app installed is simply inert. -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="liferpg" android:host="quest"/>
            </intent-filter>
```

Replace it with:

```xml
            <!-- Opens a shared quest's card via the verified Android App
                 Link below. Kept alongside a second, non-autoVerify
                 intent-filter for the legacy liferpg:// custom scheme: the
                 hosted fallback page (see the gh-pages branch's 404.html)
                 still redirects through it, and it keeps already-shared
                 old-format links working. See
                 docs/superpowers/specs/2026-09-17-quest-deep-link-app-links-design.md. -->
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="https" android:host="liferpg.lonski.pl" android:pathPrefix="/quest/"/>
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="liferpg" android:host="quest"/>
            </intent-filter>
```

- [ ] **Step 2: Verify the manifest is well-formed and the app still builds**

Run: `flutter build apk --debug`
Expected: build succeeds (this exercises AAPT2's manifest merge/parse, which would fail loudly on malformed XML or an invalid `intent-filter`/`data` attribute combination). If it fails with a manifest-merge or AAPT error, re-check the XML above for a typo before doing anything else — don't proceed to Step 3 on a red build.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: PASS, unchanged — nothing in the Dart test suite touches the manifest directly.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "$(cat <<'EOF'
feat: add verified App Link intent-filter for liferpg.lonski.pl

Lets a tapped https://liferpg.lonski.pl/quest/<id> link open the app
directly once assetlinks.json is live (see the gh-pages branch and
the design spec). The legacy liferpg://quest intent-filter stays for
the hosted fallback page and old-format shared links.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `gh-pages` branch — static site (assetlinks.json + fallback page)

**Files:**
- Create (on a new `gh-pages` branch, via a separate `git worktree`, not on `master`):
  - `CNAME`
  - `.nojekyll`
  - `.well-known/assetlinks.json`
  - `404.html`
  - `index.html`

**Interfaces:**
- Consumes: the two SHA-256 fingerprints and the package name from Global Constraints above; the domain `liferpg.lonski.pl`.
- Produces: nothing consumed by other tasks in this repo — this is what Android's Digital Asset Links check fetches over HTTPS once GitHub Pages + DNS are live (both manual steps, see the end of this plan).

- [ ] **Step 1: Create the worktree for the new orphan branch**

From the main `liferpg` checkout:

```bash
git worktree add --orphan -b gh-pages ../liferpg-gh-pages
```

This creates `../liferpg-gh-pages` as a second working directory, checked out to a new, empty (unborn — no commits yet), branch called `gh-pages`. It shares the same `.git` object store as the main checkout but has its own independent working tree and index, so nothing here touches `master`.

- [ ] **Step 2: Add `CNAME`**

Create `../liferpg-gh-pages/CNAME`:

```
liferpg.lonski.pl
```

- [ ] **Step 3: Add `.nojekyll`**

Create an empty file at `../liferpg-gh-pages/.nojekyll` (zero bytes — its mere presence, not its content, disables GitHub Pages' default Jekyll processing, which would otherwise silently drop the dot-prefixed `.well-known/` folder).

- [ ] **Step 4: Add `.well-known/assetlinks.json`**

Create `../liferpg-gh-pages/.well-known/assetlinks.json`:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.liferpg.app",
      "sha256_cert_fingerprints": [
        "21:5D:77:BC:1D:35:8D:72:1E:C5:36:AB:ED:CC:89:AA:FA:67:62:75:7C:7E:1E:0A:4C:36:BF:ED:62:D7:50:E3",
        "66:87:6C:F7:90:64:F8:E8:AE:C7:2B:55:7D:0D:1D:C9:65:37:12:66:78:A0:6F:A4:29:83:CB:07:93:CC:6B:AA"
      ]
    }
  }
]
```

- [ ] **Step 5: Validate the JSON, then add `404.html` and `index.html`**

Run: `python3 -m json.tool ../liferpg-gh-pages/.well-known/assetlinks.json`
Expected: it pretty-prints the same structure back with no error — confirms valid JSON syntax before it ever reaches Google's verifier.

Create `../liferpg-gh-pages/404.html`:

```html
<!doctype html>
<html lang="pl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>LifeRPG</title>
<style>
  body {
    font-family: system-ui, sans-serif;
    background: #1b1512;
    color: #f2e8d8;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    margin: 0;
    padding: 24px;
    box-sizing: border-box;
  }
  .card { max-width: 420px; text-align: center; }
  a.button {
    display: inline-block;
    margin-top: 16px;
    padding: 12px 20px;
    background: #8a2e2e;
    color: #f2e8d8;
    text-decoration: none;
    border-radius: 4px;
    border: 1px solid #caa53d;
    font-weight: 600;
  }
  a.link { color: #caa53d; }
</style>
</head>
<body>
  <div class="card">
    <h1>LifeRPG</h1>
    <p id="message">Zainstaluj LifeRPG, aby otworzyć ten link.</p>
    <a id="open" class="button" href="#" style="display:none">Otwórz w LifeRPG</a>
    <p><a class="link" href="https://github.com/lonski/liferpg/releases/latest">Pobierz aplikację</a></p>
  </div>
  <script>
    var segments = location.pathname.split('/').filter(Boolean);
    var isQuest = segments[0] === 'quest' && segments[1];
    if (isQuest) {
      var appUrl = 'liferpg://quest/' + segments[1];
      var openLink = document.getElementById('open');
      openLink.href = appUrl;
      openLink.style.display = 'inline-block';
      document.getElementById('message').textContent = 'Otwieranie w aplikacji...';
      location.replace(appUrl);
    }
  </script>
</body>
</html>
```

Create `../liferpg-gh-pages/index.html`:

```html
<!doctype html>
<html lang="pl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>LifeRPG</title>
<style>
  body {
    font-family: system-ui, sans-serif;
    background: #1b1512;
    color: #f2e8d8;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    margin: 0;
    padding: 24px;
    box-sizing: border-box;
    text-align: center;
  }
  a { color: #caa53d; }
</style>
</head>
<body>
  <div>
    <h1>LifeRPG</h1>
    <p>To jest strona techniczna aplikacji LifeRPG na Androida.</p>
    <p><a href="https://github.com/lonski/liferpg/releases/latest">Pobierz najnowszą wersję</a></p>
  </div>
</body>
</html>
```

- [ ] **Step 6: Commit on the `gh-pages` branch**

```bash
cd ../liferpg-gh-pages
git add CNAME .nojekyll .well-known/assetlinks.json 404.html index.html
git commit -m "$(cat <<'EOF'
feat: static site for liferpg.lonski.pl quest deep links

assetlinks.json backs the verified Android App Link added on master
(see docs/superpowers/specs/2026-09-17-quest-deep-link-app-links-design.md
there). 404.html is the de-facto handler for /quest/<id> — GitHub
Pages has no server-side routing, so any unmatched path lands here —
and redirects into the app via the legacy liferpg:// scheme, or
offers the latest GitHub Release if the app isn't installed.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
cd -
```

- [ ] **Step 7: STOP — confirm with the user before pushing**

Do not run `git push` yet. Report back to the user: the `gh-pages` branch is committed locally at `../liferpg-gh-pages` with the 5 files above, and ask them to explicitly confirm before it's pushed to `origin` (this is the point where the site becomes live and publicly fetchable — a shared-state action per this project's safety conventions, not something to do on implicit approval).

Once the user explicitly confirms:

```bash
cd ../liferpg-gh-pages
git push -u origin gh-pages
cd -
```

- [ ] **Step 8: Remove the worktree**

Once the branch is pushed (or if the user asks to abandon this task), clean up the second working directory so it doesn't linger:

```bash
git worktree remove ../liferpg-gh-pages
```

(If Step 7's push hasn't happened yet, hold off on this — the committed-but-unpushed work lives only in that worktree.)

---

## Task 4: `CLAUDE.md` — document the new deep-link architecture

**Files:**
- Modify: `CLAUDE.md` (the "Quest deep links" paragraph under "Key Behaviors")

**Interfaces:**
- Consumes: nothing (pure documentation).
- Produces: nothing (pure documentation).

- [ ] **Step 1: Replace the paragraph**

Find this paragraph in `CLAUDE.md` (under "Key Behaviors", the last bullet):

```
- **Quest deep links**: `MainActivity` declares a second, non-`autoVerify`
  `<intent-filter>` for the `liferpg://quest/...` custom scheme (there's no
  owned domain to host `assetlinks.json` for a real Android App Link, so a
  tapped link with the app not installed is simply inert). `app_links`
  delivers the URI on cold start (`main()`) and while running/backgrounded
  (`uriLinkStream`) into a module-level `pendingQuestDeepLink` notifier; the
  `_PendingQuestLinkGate` wrapping `HomeScreen` in `main.dart` consumes it
  once a user is signed in and pushes `QuestDetailScreen` — a link that
  arrives pre-login just waits rather than opening a screen that can't yet
  read `quests/{id}` (any signed-in user can, per `firestore.rules`, so the
  screen itself never needs its own auth gate beyond that).
```

Replace it with:

```
- **Quest deep links**: shared quest links are `https://liferpg.lonski.pl/quest/<id>`
  — a verified Android App Link (`android:autoVerify="true"` intent-filter in
  `MainActivity`, `.well-known/assetlinks.json` hosted on the `gh-pages`
  branch's GitHub Pages site). A tap opens LifeRPG directly on a device that
  has it installed and where verification has propagated; otherwise Android
  opens the URL in a browser, which lands on `gh-pages`' `404.html` (GitHub
  Pages has no server-side routing, so any `/quest/<id>` path 404s into it by
  design) — that page redirects into the app via a second, legacy,
  non-`autoVerify` `<intent-filter>` for the original `liferpg://quest/...`
  custom scheme (kept for this, and so already-shared old-format links still
  work), or offers the latest GitHub Release if the app isn't installed at
  all. `lib/data/quest_deep_link.dart` builds the `https://` link and parses
  incoming URIs in either shape. `app_links` delivers the URI on cold start
  (`main()`) and while running/backgrounded (`uriLinkStream`) into a
  module-level `pendingQuestDeepLink` notifier; the `_PendingQuestLinkGate`
  wrapping `HomeScreen` in `main.dart` consumes it once a user is signed in
  and pushes `QuestDetailScreen` — a link that arrives pre-login just waits
  rather than opening a screen that can't yet read `quests/{id}` (any
  signed-in user can, per `firestore.rules`, so the screen itself never
  needs its own auth gate beyond that). See
  `docs/superpowers/specs/2026-09-17-quest-deep-link-app-links-design.md`
  for the full design.
```

- [ ] **Step 2: Re-read the surrounding section for consistency**

Read the "Quest sharing" bullet immediately above this one in `CLAUDE.md` and confirm it doesn't also claim the link is inert without the app (it currently just says the caption carries "a `liferpg://quest/<id>` deep link" — update that phrase too, to "a `https://liferpg.lonski.pl/quest/<id>` deep link", so the two bullets stay consistent).

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs: document quest deep links as verified Android App Links

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Manual steps (not automatable from this repo)

Report these to the user as remaining work once Tasks 1-4 are done and (per Task 3 Step 7) the user has confirmed pushing `gh-pages`:

1. **DNS**: add a `CNAME` record, `liferpg` → `lonski.github.io`, at whatever DNS provider hosts `lonski.pl`.
2. **GitHub Pages settings**: in the `lonski/liferpg` repo's Settings → Pages, set Source to "Deploy from a branch", branch `gh-pages`, folder `/ (root)`; set the custom domain field to `liferpg.lonski.pl`; once GitHub finishes provisioning the certificate, enable "Enforce HTTPS".
3. **Reinstall the app** after both of the above are live (Digital Asset Links verification runs at install time) to actually see the verified App Link behavior on a device — `flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<id>` per `CLAUDE.md`, or the `installing-app` skill's adb recipe for a release build.
