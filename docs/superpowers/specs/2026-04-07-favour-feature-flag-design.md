# Favour Feature Flag

**Date:** 2026-04-07

## Goal

Hide the "favour" (Przychylność) feature behind a build-time environment variable so it can be toggled without touching component code. Disabled by default.

## Approach

Build-time env var via Vite's `import.meta.env`. The flag must be explicitly set to `'true'` to enable the feature; any other value (including missing) keeps it hidden.

## Changes

### `.env`
Add:
```
VITE_FEATURE_FAVOUR=false
```

### `src/featureFlags.js` (new file)
```js
export const FEATURE_FAVOUR = import.meta.env.VITE_FEATURE_FAVOUR === 'true';
```

Single source of truth for all feature flags going forward.

### `src/components/Character/Character.jsx`
Wrap the favour emoji block (the `Box` inside the header `Box` that renders the `Sentiment*` icons) with `{FEATURE_FAVOUR && ...}`.

Also guard the `const favour = character?.favour ?? 0;` line — or leave it (harmless if unused).

### `src/components/EditCharacterDialog/EditCharacterDialog.jsx`
Wrap the Przychylność field block with `{FEATURE_FAVOUR && ...}`.

## Default

`VITE_FEATURE_FAVOUR=false` — favour is hidden in all environments unless the variable is explicitly set to `'true'`.

## Out of Scope

- No runtime toggling (no Firebase Remote Config, no localStorage)
- No UI setting to enable/disable
- Data is preserved in Firestore; only the display is hidden
