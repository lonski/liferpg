# Achievements ("Odznaki")

Mockups: https://claude.ai/artifact/PgNwW7sa3FTCvxT9qgjtNU (artboards 1–6
plus the "Rodzina odznak" sheet). Where the mockups and this document
disagree, this document wins — the mockups predate several decisions below
(no categories, no character picker, the admin's empty-state section).

## Problem

Real-life accomplishments — a podium place in a contest, a concert played, a
finished challenge — have no place in LifeRPG today. They can only be
rewarded as an anonymous change request, which leaves no lasting trace on the
character of *what* was achieved.

## Goal

An admin awards a character a **badge** (odznaka) for a specific reason. The
badge is shown on the character card and in a per-character gallery, carries
an individually chosen reward (any mix of XP, gold, one trait delta and
electronics days), notifies the owner, and can be shared as an image.

Out of scope (decided, not deferred by accident):

- Badge categories (filtering, category labels).
- Players requesting a badge — only admins award them.
- A predefined catalogue of badges — every badge is created ad hoc.
- A global / cross-character achievements board, and any visibility wider
  than the character's own.
- Deep links to a badge — sharing is image + caption only.
- Editing a badge's reward after it is awarded.
- Notifying the owner when a badge is revoked.

## Step 0 — electronics section layout (separate commit, ships first)

Independent of achievements; the user asked for the compact presentation the
mockups used. In `lib/features/character/electronics_section.dart`:

- The ring medallion shrinks from 84 px to ~52 px. The count stays; the
  `dostępne` caption is dropped (illegible at that size). Today's arc and
  the state badge (hourglass / ×) stay, scaled down.
- The `Dzisiejszy dzień` label is dropped; headline + status sit next to the
  ring.
- The action moves from a full-width button below to a compact button at the
  right end of the same row (~36 px visual height; Material's padded tap
  target keeps the hit area at 48 px). `ODBIERZ` unchanged; the pending
  state's button reads `ANULUJ` with tooltip `Anuluj prośbę` (the full label
  would squeeze the text on narrow screens).
- Widget keys (`electronics-claim`, `electronics-cancel`, `electronics-ring`,
  `electronics-count`) stay, so `electronics_panel.dart` is untouched.
  `test/features/electronics_section_test.dart` and the CLAUDE.md
  description are updated to match.

## Data model

Badges live **inside the character document**, as an array:

```
characters/{id}.achievements: [
  { id:            string        // Firestore auto-id, generated before the award transaction
    title:         string        // required, e.g. "II miejsce"
    event:         string?       // e.g. "Wojewódzki Konkurs Recytatorski"
    reason:        string?
    date:          'YYYY-MM-DD'  // local date of the accomplishment
    emblem:        'place' | 'trophy' | 'note' | 'peak' | 'book' | 'star'
    place:         1 | 2 | 3     // only meaningful with emblem == 'place'
    tier:          'gold' | 'silver' | 'bronze' | 'ruby'
    reward:        { current_xp?, gold?, traits?: [{name, value}], electronics_days? }
    awardedBy:     uid
    awardedByName: string
    awardedAt:     Timestamp     // from clockProvider, see below
  }
]
```

Why an array on the character rather than a collection: badge visibility is
by definition the character's visibility (owner, admins, `readOnlyOthers`),
which the existing `/characters` read rule already enforces; character
writes are already admin-only. So **`firestore.rules` does not change**, no
new query or index is needed (badges arrive on the existing character
stream), and the email-case caveat of an own-email query does not reappear.
Award and revoke become single-document transactions. Document growth is a
non-issue at family scale (1 MB limit).

- `awardedAt` is a client timestamp (`Timestamp.fromDate(clock())`):
  Firestore rejects `FieldValue.serverTimestamp()` inside array elements.
- Sort order everywhere: `date` descending, then `awardedAt` descending.
- `lib/models/achievement.dart`: `Achievement`, `AchievementReward`, enums
  `AchievementEmblem` / `AchievementTier` with wire names as above. Parsing is
  tolerant like `Character.fromMap`: an entry without a string `id` or a
  non-empty `title` is dropped; an unknown emblem reads `star`, an unknown
  tier `gold`; `place` outside 1–3 reads null, and `emblem: place` without a
  valid place renders as `trophy`; a bad `date` falls back to the
  `awardedAt` day; non-numeric reward entries are dropped.
- `AchievementReward` is its own class, **not** an extension of `ChangeSet`:
  adding `electronics_days` to `ChangeSet` would let the key ride in an
  ordinary change request, which the create rule does not forbid. It holds
  `currentXp`, `gold`, `trait` (one `TraitChange`, matching the existing
  single-trait request form) and `electronicsDays`, plus `negated()` and a
  `toChangeSet()` view of the XP/gold/trait part.
- `Character` gains `List<Achievement> achievements` (from `fromMap`);
  **`Character.toMap()` omits it**, exactly like `electronics`, so the edit
  screen's `update(toMap())` can never overwrite a badge awarded while it was
  open.

## Operations — `lib/data/achievement_repository.dart`

All three run `runTransaction` on the character document, on the admin's
device.

- **`award(characterId, draft, admin)`**: reads the character (throws
  `AchievementCharacterGone` if missing). If an entry with the draft's `id`
  already exists the transaction is a no-op (double tap). Otherwise appends
  the entry and applies the reward in the same `tx.update`.
- **`edit(characterId, achievementId, details)`**: replaces only `title`,
  `event`, `reason`, `date`, `emblem`, `place`, `tier`. `reward` and the
  `awarded*` fields are untouched. Throws `AchievementGone` if the entry is
  no longer there.
- **`revoke(characterId, achievementId)`**: removes the entry and applies
  `reward.negated()`. If the entry is already gone it is a no-op, so a double
  tap cannot reverse twice.

Reward semantics (shared by award and revoke):

- XP / gold / trait are **deltas with change-request semantics**. The delta
  logic in `ChangeRequestRepository._applyTo` (XP `.toInt()`, gold stays
  `num`, tolerant coercion of legacy non-numeric values to 0, trait matched
  by name and added to, a new name appended with the delta as its starting
  value) moves into a pure, shared function (e.g.
  `lib/models/character_deltas.dart`) used by both repositories. Change
  request behaviour must not change — its existing tests guard this.
- Values **may go negative** on revoke (XP, gold, trait value). A trait that
  reaches 0 stays on the card; there is still no remove operation.
- Electronics days: new `ElectronicsDays.addDays(int delta, int today)` —
  settle first (`days += accrued; as_of = max(as_of, today)`), then
  `days = max(0, days + delta)`. So a revoke clamps electronics at 0 (the
  one exception to "may go negative", consistent with `applyClaim`).
- Only the fields the reward touches are written, so an XP-only badge never
  invents `gold: 0`.

## Screens — `lib/features/achievements/`

**`AchievementBadge`** — the medal from the "Rodzina odznak" sheet, one
widget for every size (32–150 px). A `CustomPainter` draws the ribbon tails,
the tier-gradient ring, the milled (dashed) edge, the crimson disk and the
✦ marks. The emblem is a Material icon (`emoji_events`, `music_note`,
`landscape`, `menu_book`, `star`) or, for `place`, a Roman numeral I/II/III
in Marcellus. Tier colours (light / mid / dark / emblem) are new
`const Color` literals in `app_theme.dart`; ruby uses a gold rim so it reads
against the crimson disk.

**Character card section** — an `achievements` slot on `CharacterCard`
below Cechy, built like the `electronics` slot:

- Players and `readOnlyOthers`: shown **only when the character has at least
  one badge**.
- Admins: **always** shown. With no badges it reads `Brak odznak` and offers
  **PRZYZNAJ ODZNAKĘ**.
- Labelled divider `Odznaki · N`, the 4 newest badges (tap → detail), a
  `NOWA` chip on badges awarded within the last 7 days (by `clockProvider`,
  no seen-state), and `WSZYSTKIE ODZNAKI ›` → gallery.

**`AchievementsScreen`** (gallery) — tier summary row and a 3-column grid,
newest first. Admins get a `+` AppBar action → award form.

**`AchievementDetailScreen`** — large badge, title, event, reason,
`Przyznano` / `Przyznał`, reward tiles. **Udostępnij** for everyone who can
see it. Admins also get **Edytuj** (form in edit mode) and **Usuń**, gated on
`showConfirmDialog` whose text lists exactly what will be taken back, e.g.
`Cofnięte zostanie: −150 XP, −50 zł, Recytacja −1, −2 dni elektroniki`.

**`AwardAchievementScreen`** (award + edit):

- No character picker: always entered from a character's context; title
  `Przyznaj odznakę · <name>`.
- `Zajęte miejsce`: I / II / III / brak. Picking a place sets emblem `place`
  and tier gold/silver/bronze and pre-fills the title (`II miejsce`); both
  remain overridable. Picking `brak` while the emblem is `place` switches it
  to `trophy`.
- Emblem picker (6), tier picker (4), live badge preview.
- `Tytuł` (required), `Wydarzenie`, `Powód` (optional), `Data` — a
  `RRRR-MM-DD` text field validated by `parseDay`, default today via
  `clockProvider`. Not `showDatePicker`: the app ships no Polish Material
  localizations, so the picker would render in English.
- Reward: XP / gold / one trait via the existing `ChangeRequestForm` with
  `showReason: false`; electronics days via a −/+ field like the edit
  screen's. A summary line `<name> otrzyma …` above **PRZYZNAJ**.
- Edit mode: the reward is read-only with the note
  `Aby zmienić nagrodę, usuń odznakę i przyznaj ją ponownie.`

`readOnlyOthers` see section, gallery and detail and may share; no admin
actions anywhere.

## Notifications and the "Nowa odznaka" dialog

- Recipients: the **owner** only (character email matches the signed-in
  user's, the same ownership test the home screen uses for the FAB) — an
  admin awarding someone else's character is not notified; an admin awarding
  their own character is.
- `lib/providers/achievement_notification_providers.dart` rides the existing
  character stream, same approach as quest / change-request notifications
  (fires only while the process is alive).
- `AchievementNotificationRepository` (SharedPreferences, per uid, `null` =
  no baseline yet) keeps two id sets:
  - **notified** — system-tray notification sent (`Nowa odznaka: <title>`,
    body `<name> · <reward summary>`);
  - **celebrated** — the in-app dialog was dismissed. An id enters this set
    only when the dialog closes, so a dialog is never lost to the app being
    killed first; it shows on next launch.
- The first snapshot after install seeds both sets silently. Several new
  badges show their dialogs one after another. Ids no longer present are
  dropped from both sets.
- Dialog (mockup artboard 4): gold band `✦ Nowa odznaka ✦`, badge with rays,
  tier label, title, event, `Otrzymujesz` reward chips, **UDOSTĘPNIJ** and
  **WSPANIALE** (closes).
- Revoke sends nothing.

## Sharing

- `AchievementShareCard` (mockup artboard 6): character name and class,
  badge with rays, title, event, reason, reward chips, date, `LIFERPG`
  footer band.
- From `quest_share.dart`, extract the offscreen capture into a shared
  `captureWidgetImage(context, widget, {width})`. Rename `QuestShareService`
  → `ShareService` (it has nothing quest-specific; same for the share_plus
  implementation and the provider). Quest sharing behaviour is unchanged.
- Caption: `<name> — odznaka „<title>”` plus ` (<event>)` when present.
  Worded so the name stays in the nominative: characters carry no
  grammatical gender and names cannot be declined automatically
  (`Odznaka dla Zosia` would be wrong). **No link.** A failed capture falls back to text-only, as quests
  do.
- Entry points: detail screen icon and the dialog's **UDOSTĘPNIJ**.

## Testing

- Pure: `Achievement` / `AchievementReward` parsing (tolerance cases above),
  `negated()`, the extracted delta function (existing change-request tests
  pass unchanged), `ElectronicsDays.addDays` (settles first, clamps at 0).
- Repository (`fake_cloud_firestore`): award applies the reward and is
  idempotent per id; edit leaves the reward alone and throws when gone;
  revoke reverses, allows negative XP/gold/trait, clamps electronics, is a
  no-op when gone; `CharacterRepository.update(toMap())` preserves
  `achievements`.
- Widgets: section visibility (player/readOnly with none → hidden; admin
  with none → `Brak odznak` + button), gallery, detail admin actions and the
  revoke confirm text, form defaults from place and read-only reward in edit
  mode, sharing via a fake `ShareService` including the text-only fallback.
- Notifications: silent seeding, new badge → notification + dialog, dialog
  re-shown after restart if never dismissed, non-owner not notified.
- `tools/rules-test`: no changes (rules unchanged).

## Docs

CLAUDE.md gains the `achievements` array in the Firestore data model, a Key
Behaviors entry for badges (who sees the section, award/edit/revoke
semantics, the `toMap()` omission, client `awardedAt`), the notification
pair, and the `ShareService` rename; the electronics section description is
updated for Step 0.
