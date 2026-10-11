# Bossowie — design

Mockups: https://claude.ai/artifact/2XDfQUT8pEuy113qxy4BuM (arena under the
card, fight on the card, spellbook in three themes, summon form, gallery).

## What it is

An admin summons a boss (look, name, HP, reward, target: everyone or one
character). It walks back and forth in an arena **under each targeted
character's card**. The owner picks a blow from their weapon, taps the boss,
a short fight plays on the card, HP drops, the boss walks on. At 0 HP it is
beaten; every character that dealt at least 1 damage collects the reward.

## Data

`bosses/{id}`

```
name, look ('smok'|'rycerz'|'wiedzma'|'upior'|'troll'|'golem'|'kosciej'|'kraken')
maxHp, hp (int)
reward: { current_xp?, gold?, traits?: [{name, value}] }   (deltas)
targetCharacterId, targetCharacterName   (null = everyone)
status: 'active' | 'defeated' | 'cancelled'
createdAt (server), createdBy, createdByName
baseline: { <characterId>: current_xp when the boss appeared }
spent:    { <characterId>: energy spent }
damage:   { <characterId>: damage dealt }
rewarded: { <characterId>: true }
lastAttackerId, lastAttackerName, lastJoinedId, lastClaimId, defeatedAt
```

`characters/{id}` gains `weapon` ('miecz'|'luk'|'maczuga'|'miotla'|'ksiega',
admin-set, in `toMap()`) and `lastBossRewardId` (written only by a reward
claim, never by `toMap()`).

## Rules of play

- **Weapon**: the admin-set `weapon` if any, else the class default:
  Barbarzyńca → maczuga, Pani domu → miotła, Czarodziej(ka) → księga zaklęć
  (case-insensitive). With neither the character cannot attack ("Brak
  broni — poproś admina").
- **Blows**: four tiers for every weapon, cost → damage: 1 → 1, 10 → 10,
  50 → 60, 100 → 150. Names per weapon (Iskra / Kula ognia / Lodowa burza /
  Deszcz meteorów for the book, …).
- **Energy** ("energia bojowa") = `max(0, current_xp − baseline − spent)`:
  XP gained since the boss appeared, minus what blows used. XP and level are
  untouched. The admin writes `baseline` for every targeted character at
  summon time; a character missing from it (created later) gets its own
  baseline written by its owner's client the first time the arena shows.
  An admin lowering `current_xp` by hand (a level-up reset) lowers energy
  too; it never goes below 0.
- **Attack** (owner's client, transaction): re-reads boss and character,
  checks active / targeted / energy, then writes hp, spent, damage, and on
  0 HP `status: defeated` + `defeatedAt`.
- **Reward**: an owner (or admin) taps ODBIERZ NAGRODĘ on the beaten boss.
  One transaction applies the reward with `applyCharacterDeltas` and adds
  the character to `rewarded`.
- An admin can cancel an active boss (it disappears).

## Security rules

- `bosses`: read for any signed-in user; create/delete admin; update admin,
  or one of three owner paths, each naming the character in a `last*Id`
  field so the rule can check it:
  - attack — only hp/damage/spent/status/defeatedAt/lastAttacker*; one
    character's entries change, by exactly one tier's cost/damage pair;
    new `spent ≤ current_xp − baseline` (read off the character);
    hp drops by the damage (or to 0 with `status: defeated`).
  - join — adds the caller's own missing baseline, equal to the
    character's `current_xp`.
  - claim — adds the caller's character to `rewarded` on a defeated boss it
    damaged, only together with the character write below.
- `characters`: besides admin writes, the owner may update their own
  character in a reward claim: only current_xp/gold/traits/lastBossRewardId,
  XP and gold exactly `+reward`, traits list growing by at most the reward's
  trait count, the boss defeated, damaged by them, not yet rewarded before
  and rewarded after (getAfter). Trait values themselves are not verified
  (rules cannot loop); this is the one trusted part.

## UI

- `BossArena` under the card: themed band "BOSS", name + HP bar, a floor
  (stone / yard / forest) with the walking boss, a weapon button + energy.
  For the owner their character (`HeroPainter`, dressed by weapon) stands
  on the floor: a tap on the ground walks it there; with a blow picked, a
  tap on the boss walks it up (sword, club, broom) or turns it to face the
  boss (bow, book) and plays the blow (`FightFxPainter`).
  Weapon tap → blow picker (księga: an open spellbook turning pages; other
  weapons: a sheet). Picked blow → banner "… — stuknij bossa!", the boss
  pulses; tap → the hero's attack (slash arcs and sparks, arrows or a
  volley or a lightning arrow, a spark / fireball / ice shards / meteors),
  flash + shake, floating "−N", the HP bar drops as the blow lands; the
  boss stops while fought and walks again after.
- Beaten boss: the arena becomes a victory panel (reward chips, fighters,
  ODBIERZ NAGRODĘ for owner/admin).
- Admin: "Przywołaj bossa" button on the home list → `SummonBossScreen`
  (look grid incl. Losowy, name, HP chips, XP / gold / several traits,
  Wszyscy / Wybrana postać); cancel (×) on the arena band.
- Edit character: BROŃ picker for every class ("domyślna" = the class default).
- Theme: `RpgTheme.arena` (`BossArenaPalette`) holds every arena/book
  colour; `RpgDecor.arenaFloor`, `spellbookKeeper`, `spellbookSeal`,
  `sealedSpellLabel` give the per-theme details.
