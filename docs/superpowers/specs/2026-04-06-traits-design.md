# Traits (Cechy) Feature Design

**Date:** 2026-04-06  
**Status:** Approved

## Overview

Add a "Cechy" (Traits) section to each character card displaying RPG-style numeric attributes. Admins can add, remove, and edit traits per character via the existing edit dialog.

## Data Model

Add a `traits` field to each character document in Firestore:

```js
{
  name: "Helonator",
  // ...existing fields...
  traits: [
    { name: "Siła", value: 12, type: "number" },
    { name: "Zręczność", value: 8, type: "number" }
  ]
}
```

- Type: array of `{ name: string, value: number, type: string }` objects
- `type` defaults to `"number"` when adding a new trait; reserved for future extension (e.g. `"text"`, `"boolean"`)
- Order is preserved (array, not map)
- Field is optional — characters without `traits` (or with empty array) simply don't show the section
- Values are integers only (for `type: "number"`)

## Character Card (`Character.jsx`)

A new "Cechy" section is rendered below the existing money `<Box>`, only when `character.traits?.length > 0`.

**Layout:**
- MUI `Typography` overline: "Cechy" label (same style as the class label)
- One row per trait using `Box display="flex" justifyContent="space-between"`
- Left: trait name as `Typography`
- Right: trait value as MUI `Chip` — `color="primary"`, `variant="outlined"`, `size="small"`

## Edit Dialog (`EditCharacterDialog.jsx`)

A "Cechy" section is added below the "Dolary" row. It is divided into two parts:

### Existing traits list

One inline row per trait in `character.traits`:
- Name: read-only `Typography` (names are not editable after creation — only the value)
- Value: `<Input type="number">` bound to the trait's value in local state
- Delete: `IconButton` with `DeleteIcon` — removes the trait from the array

### Add new trait row

A combobox + value input + add button:
- **Name**: MUI `Autocomplete` with `freeSolo` prop
  - Options: all unique trait names collected from all characters currently in React Query cache (`["characters"]` query data) — no extra Firestore call
  - Typing filters options; if typed text matches nothing, a `"+ Dodaj 'X'"` option is shown (standard `freeSolo` + `filterOptions` with `createOption` pattern)
  - Selecting an existing option or confirming a new one fills the name field
- **Value**: `<Input type="number">` starting at 0
- **Add button**: `IconButton` with `AddIcon` — appends `{ name, value: Number(value), type: "number" }` to `character.traits` in local state and resets the add row

### Save behaviour

`handleSave` already writes the full `character` object to Firestore via `updateDoc`. No changes needed to the save logic — `traits` is included automatically.

## Scope

- No changes to `useCharacters.js` or `firebase.js`
- No new hooks or components — traits are rendered inline in `Character.jsx` and `EditCharacterDialog.jsx`
- Trait names are not editable after creation (only values and delete)
- No validation beyond requiring a non-empty name before adding
