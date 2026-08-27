---
name: releasing-app
description: Use when asked to release, ship, cut, publish, or tag a new version of the LifeRPG Android app — the request will mention "release", "publish a build", "tag a version", or similar, for this repo specifically.
---

# Releasing the App

## Overview

There is no manual APK build/upload step. Pushing a tag matching `v*`
triggers `.github/workflows/android-release.yml`, which analyzes, runs
`flutter test` and the Firestore rules emulator suite, builds a **signed**
release APK, and publishes it as a GitHub Release attached to that tag.
Pushing to `master` does **not** trigger a release — only the tag push does.
(Firebase App Distribution is temporarily removed from that workflow — a
403'ing service account — so distribution today is the GitHub Release only;
see `CLAUDE.md`'s CI/CD section, which is authoritative over this file if
the two ever disagree.)

## Steps

1. Check whether a release is already in flight or already published for
   the commit you're about to ship: `git tag --points-at HEAD` and
   `gh run list --workflow=android-release.yml --limit 5`. If one is
   running or already succeeded for this commit, don't cut another — report
   that to the user instead of duplicating it. Only proceed past this step
   if there's genuinely nothing shipped yet for what you're about to tag.
2. Confirm the changes to ship are committed on `master` (this repo commits
   release-worthy fixes straight to master — no release branch). "The
   changes to ship" means everything merged since the last tag, as a batch —
   don't bump per-commit.
3. Read the current `version:` in `pubspec.yaml` — format `X.Y.Z+B`
   (semver + build number). Decide the bump for the whole batch: patch for
   fix(es) only, minor if any feature is included, and always increment `B`
   by 1 regardless. If the right bump isn't obvious from the changes being
   shipped, ask rather than guess.
4. Edit `pubspec.yaml`'s `version:` line.
5. Locally run `flutter analyze` and `flutter test` before committing —
   CI runs these too and a tag push cannot be "retried" onto the same tag,
   so catch failures here rather than burning a release cycle.
6. Commit it (`git add pubspec.yaml` + whatever else is part of the release)
   and push `master`.
7. Tag using **just the semver part** of the pubspec version, prefixed with
   `v` (drop the `+build` suffix — it's Android/iOS build-number
   bookkeeping, not part of the release's public name):
   `git tag -a v<X.Y.Z> -m "<summary>"`.
   The `-m` message becomes the tag's annotation and is what
   `action-gh-release` shows as the release notes, so write a terse,
   human-readable summary of what this release actually contains (e.g.
   `"Change-request review flow; fix tiny form field labels"`) — not just
   the version number repeated.
8. Pushing the tag is what actually fires the release build and creates a
   public GitHub Release with a downloadable APK — treat it as the
   consequential step and confirm with the user before running
   `git push origin v<X.Y.Z>`, even if steps 1-6 were already approved.

## Gotchas

- Tag must start with `v` to match the workflow's `tags: 'v*'` trigger.
- Tag name is semver only (`v1.0.2`), never the `+build` suffix — keeps
  tags/releases human-readable; the build number still lives in
  `pubspec.yaml` for Android/iOS's sake.
- The workflow runs `flutter analyze`, `flutter test`, and the Firestore
  rules suite before building; if any fail, no GitHub Release is created.
  Fix and push a *new* tag — don't force-push over the failed one.
- No local signing needed: CI restores `android/key.properties` and the
  keystore from secrets (see `android-release.yml`).
- Don't force-push or delete/retag an already-pushed release tag to "fix"
  it — cut a new version instead.

## Example

`version: 1.0.1+2` in `pubspec.yaml`, a bugfix is ready on `master`, nothing
already tagged for this commit → bump to `1.0.2+3`, `flutter analyze &&
flutter test` locally, commit, push `master`,
`git tag -a v1.0.2 -m "Fix tiny form field labels in edit dialogs"`,
confirm, `git push origin v1.0.2`.
