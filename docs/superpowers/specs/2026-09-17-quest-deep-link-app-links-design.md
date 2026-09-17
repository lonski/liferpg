# Quest deep links as verified Android App Links

## Problem

Sharing a quest (`shareQuest`, `lib/features/quests/quest_share.dart`) hands
the recipient app plain text containing a `liferpg://quest/<id>` link via
Android's native share sheet. Whether a link becomes tappable is entirely up
to the *receiving* app's own linkifier, and every tested app (Signal
confirmed, WhatsApp/SMS presumed) only auto-linkifies `http://`/`https://`
URLs — a bare custom scheme just sits there as plain, dead text. This was a
known, accepted limitation (see `CLAUDE.md`'s Quest deep links section:
"there's no owned domain to host `assetlinks.json` ... a tapped link with
the app not installed is simply inert") — it's not fixable without an
`https://` link, which needs a verifiable domain. The user now has one:
`lonski.pl`, hosted on GitHub Pages, and wants a verified Android App Link.

## Goal

`questDeepLink(id)` produces `https://liferpg.lonski.pl/quest/<id>`, a link
that:
- renders as a normal tappable blue link in any share target (it's a real
  `https://` URL)
- opens LifeRPG directly, no browser hop, when the app is installed and the
  domain is verified (a real Android App Link)
- falls back to a small hosted web page when the app isn't installed (or
  verification hasn't propagated yet), which itself tries to hand off to the
  app via the legacy `liferpg://` scheme and otherwise offers the APK

Out of scope: an installable web app, a real quest-details fallback page (the
static site has no Firestore/auth access and quest data requires a signed-in
user per `firestore.rules` — the fallback page can only ever be a generic
"open in the app" nudge), iOS universal links (this project is Android-only).

## Architecture

```
shareQuest ──▶ https://liferpg.lonski.pl/quest/<id>  (share sheet text)
                          │
                    recipient taps
                          │
                          ▼
              Android checks verified App Links
                 │                        │
         app installed +              app not installed,
         domain verified              or verification not
                 │                     yet propagated
                 ▼                        ▼
         LifeRPG opens directly    browser opens the URL
         (QuestDetailScreen,             │
          existing pendingQuestDeepLink   ▼
          plumbing in main.dart)   404.html (GitHub Pages
                                    has no path routing, so
                                    any /quest/<id> 404s into
                                    this page) tries
                                    liferpg://quest/<id> via
                                    JS, else shows an "Open in
                                    LifeRPG" button + a link to
                                    the latest GitHub Release
```

### Why a `gh-pages` branch, not `docs/` on `master`

`docs/` on `master` already holds `docs/superpowers/specs/*.md` (this file
included). Pointing GitHub Pages at `docs/` would publish those internal
design docs as pages on the live domain, which is unrelated to this feature
and produces a messy public site. A dedicated `gh-pages` branch keeps the
published file tree exactly the intended handful of static files, independent
of anything committed to `master`.

### Why both scheme intent-filters stay

The manifest keeps the existing `liferpg://quest` intent-filter alongside the
new `https://liferpg.lonski.pl/quest/*` one with `android:autoVerify="true"`.
The custom scheme isn't dead weight: `404.html`'s JS fallback still targets
it, and it's forward/backward compatible with the small number of links
already shared under the old scheme.

### Why both signing certs go in `assetlinks.json`

`sha256_cert_fingerprints` is an array on a single target entry — both the
release keystore's and the debug keystore's SHA-256 fingerprints go in it, so
verification also passes for a debug build (`flutter run`), not only a
release APK. Digital Asset Links verification is per installed app signature;
without the debug fingerprint, tapping a shared link while running a debug
build would silently fall through to the browser fallback with no visible
error, which is confusing during development.

Fingerprints (already extracted via `keytool -list -v`, matches this
project's `android/key.properties` release keystore and the machine's
`~/.android/debug.keystore`):
- release: `21:5D:77:BC:1D:35:8D:72:1E:C5:36:AB:ED:CC:89:AA:FA:67:62:75:7C:7E:1E:0A:4C:36:BF:ED:62:D7:50:E3`
- debug: `66:87:6C:F7:90:64:F8:E8:AE:C7:2B:55:7D:0D:1D:C9:65:37:12:66:78:A0:6F:A4:29:83:CB:07:93:CC:6B:AA`

Package name (from `android/app/build.gradle.kts`): `com.liferpg.app`.

## Components

### 1. `gh-pages` branch (new, static files, root-served)

- **`CNAME`** — single line, `liferpg.lonski.pl`. Tells GitHub Pages which
  custom domain this branch answers to.
- **`.nojekyll`** — empty file. GitHub Pages runs the content through Jekyll
  by default, which ignores dot-prefixed files/folders (including
  `.well-known/`) unless this marker disables that processing.
- **`.well-known/assetlinks.json`**:
  ```json
  [{
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.liferpg.app",
      "sha256_cert_fingerprints": [
        "21:5D:77:BC:1D:35:8D:72:1E:C5:36:AB:ED:CC:89:AA:FA:67:62:75:7C:7E:1E:0A:4C:36:BF:ED:62:D7:50:E3",
        "66:87:6C:F7:90:64:F8:E8:AE:C7:2B:55:7D:0D:1D:C9:65:37:12:66:78:A0:6F:A4:29:83:CB:07:93:CC:6B:AA"
      ]
    }
  }]
  ```
  Must be served over HTTPS, no redirects, `Content-Type: application/json`
  (GitHub Pages serves `.json` with the right content type out of the box).
- **`404.html`** — the de facto handler for `/quest/<id>` (GitHub Pages has
  no server-side routing, so any unmatched path 404s into this file, which
  is intentional here). Plain HTML/JS, no build step:
  - reads the quest id off `location.pathname`'s last non-empty segment
  - if the path starts with `/quest/`, attempts
    `location.replace('liferpg://quest/' + id)` on load, and renders a
    visible "Otwórz w LifeRPG" button doing the same (in case the automatic
    attempt is blocked, which some browsers do for unrecognized schemes) —
    Polish, matching the rest of the app's UI language per `CLAUDE.md`
  - always shows a link to
    `https://github.com/lonski/liferpg/releases/latest` for someone without
    the app installed
  - a path that doesn't start with `/quest/` (a typo, a stale/garbage link)
    shows just the generic "install the app" content, no broken quest-id
    handling
- **`index.html`** — minimal static page (a sentence + the same Releases
  link) so the bare domain isn't a dead 404 if anyone visits it directly.

### 2. `android/app/src/main/AndroidManifest.xml`

Add, alongside the existing custom-scheme `intent-filter` (kept as-is):

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="https" android:host="liferpg.lonski.pl" android:pathPrefix="/quest/"/>
</intent-filter>
```

### 3. `lib/data/quest_deep_link.dart`

- `questDeepLink(id)` → `'https://liferpg.lonski.pl/quest/$id'` (was
  `'liferpg://quest/$id'`).
- `questIdFromDeepLink(uri)` accepts **both** shapes, so a link already
  shared under the old scheme before this change still opens correctly:
  - `https` + host `liferpg.lonski.pl` + first path segment `quest` + a
    non-empty second path segment → that segment is the id
  - `liferpg` scheme + host `quest` + non-empty first path segment (existing
    behavior, unchanged) → that segment is the id
  - anything else → `null`, same as today

No change needed in `main.dart`'s `pendingQuestDeepLink` plumbing or
`app_links` wiring — it already forwards whatever URI the OS hands it into
`questIdFromDeepLink`, regardless of scheme.

### 4. `CLAUDE.md`

The existing "Quest deep links" paragraph under Key Behaviors states there's
no owned domain and a link without the app installed "is simply inert" —
replace that with the App Links architecture above (domain, verified
App Link, `gh-pages` fallback page, dual-scheme back-compat).

## Manual steps (outside this repo's automation)

1. **DNS**: add a `CNAME` record, `liferpg` → `lonski.github.io`, at the
   `lonski.pl` DNS provider.
2. **GitHub Pages settings**: after the `gh-pages` branch is pushed, enable
   Pages on `lonski/liferpg` with source = branch `gh-pages`, folder `/`
   (root), and set the custom domain to `liferpg.lonski.pl` (GitHub will also
   offer to enforce HTTPS once the cert provisions — turn that on).

Both are user actions; pushing the new branch itself is a shared-state
action this session will pause for confirmation on before doing.

## Testing

`test/data/quest_deep_link_test.dart` (pure functions, no Flutter
dependency) gets cases for:
- `questDeepLink` returns the new `https://liferpg.lonski.pl/quest/<id>`
  shape
- `questIdFromDeepLink` parses that shape back to the id
- `questIdFromDeepLink` still parses the legacy `liferpg://quest/<id>` shape
  (back-compat regression coverage)
- existing negative cases (wrong host/scheme, empty id, etc.) — audit
  current tests and extend rather than duplicate

No widget-level test changes expected: `main.dart`'s deep-link gate consumes
`questIdFromDeepLink`'s output as an opaque id string and doesn't care which
URI shape produced it.

## Risks / edge cases considered

- **Verification propagation delay**: Android's Digital Asset Links check
  happens at install/update time and can take a little while after DNS/Pages
  first go live; until then, taps fall through to the browser fallback page
  rather than erroring — acceptable, matches the designed fallback path.
- **Debug builds**: covered by including the debug fingerprint in
  `assetlinks.json` (see above).
- **Old shared links**: covered by `questIdFromDeepLink` accepting both
  shapes.
- **GitHub Pages Jekyll eating `.well-known/`**: covered by `.nojekyll`.
