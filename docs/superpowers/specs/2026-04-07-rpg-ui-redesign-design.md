# RPG UI Redesign — Design Spec

**Date:** 2026-04-07
**Status:** Approved

---

## Overview

Redesign the LifeRPG UI from generic MUI defaults to a full-app RPG aesthetic. The chosen style is a **Burgundy Decree** — warm parchment cards with deep red header/footer bands, ornate inner frames, and Cinzel typography. The theme extends across the entire app: cards, AppBar, Login page, and Edit dialog.

---

## Visual Style

**Card style:** Burgundy Decree (R2-B)
- Parchment background: `radial-gradient(ellipse at 50% 0%, #f5e8d0, #e0ccaa, #c8b080)`
- Burgundy border: `2px solid #6b1a1a`
- Header/footer bands: `linear-gradient(90deg, #3a0a0a, #7a1414, #3a0a0a)`
- Inner frame: `1px solid rgba(107,26,26,0.35)` with `❧` corner ornaments
- Fleur-de-lis divider: gradient lines flanking a `✦` glyph

**Typography:**
- Headings / labels / caps: **Cinzel** (Google Fonts) — `font-weight: 700`, `letter-spacing: 2–4px`
- Body / italic labels: **Libre Baskerville** (Google Fonts)
- Loaded via `<link>` in `index.html`

**App background:** `#1a1008` (very dark warm brown)

**Colour palette:**
| Token | Value | Usage |
|---|---|---|
| primary.main | `#7a1414` | Buttons, focused states |
| primary.dark | `#3a0a0a` | AppBar, band backgrounds |
| background.default | `#1a1008` | Page background |
| background.paper | `#e0ccaa` | Cards, dialogs |
| text.primary | `#1a0a0a` | Body text |
| accent.gold | `#c8860a` | XP bar fill end, decorative glows |

---

## Architecture

**New files:**
- `src/theme.js` — MUI `createTheme()` export; imported once in `App.jsx` via `<ThemeProvider>`
- `src/components/Character/Character.module.css` — card-specific decoration (bands, inner frame, corner ornaments, trait pills)
- `src/components/Login/Login.module.css` — login page layout and logo styling

**Modified files:**
- `index.html` — add Google Fonts `<link>` for Cinzel + Libre Baskerville
- `src/App.jsx` — wrap with `<ThemeProvider theme={theme}>`
- `src/App.css` — update `body` background to `#1a1008`
- `src/components/Character/Character.jsx` — apply RPG card structure and feature flag
- `src/components/Home/Home.jsx` — apply styled AppBar
- `src/components/Login/Login.jsx` — apply RPG login layout
- `src/components/EditCharacterDialog/EditCharacterDialog.jsx` — apply RPG dialog structure

---

## MUI Theme (`src/theme.js`)

```js
createTheme({
  palette: {
    primary: { main: '#7a1414', dark: '#3a0a0a' },
    background: { default: '#1a1008', paper: '#e0ccaa' },
    text: { primary: '#1a0a0a' },
  },
  typography: {
    fontFamily: "'Libre Baskerville', Georgia, serif",
    h1: { fontFamily: "'Cinzel', serif" },
    h2: { fontFamily: "'Cinzel', serif" },
    h3: { fontFamily: "'Cinzel', serif" },
    h4: { fontFamily: "'Cinzel', serif" },
    overline: { fontFamily: "'Cinzel', serif", letterSpacing: '3px' },
  },
  components: {
    MuiLinearProgress: {
      // parchment track, burgundy-to-gold fill
    },
    MuiChip: {
      // parchment border, dark text, pill shape
    },
    MuiButton: {
      // contained: burgundy; outlined: parchment border
    },
    MuiDialog: {
      // paper background: parchment
    },
  },
})
```

---

## Character Card (`Character.jsx` + `Character.module.css`)

**Structure:**
```
<div class="card">               ← border, border-radius, box-shadow, parchment bg
  <div class="topBand">          ← burgundy gradient, "✦ Karta Postaci ✦" in Cinzel
    [admin only: edit icon ✎]
  </div>
  <div class="body">
    <div class="innerFrame">     ← 1px border, ❧ corner ornaments
      <name>                     ← Cinzel 22px bold, letter-spacing 2px
      <class>                    ← Cinzel 9px, letter-spacing 4px, uppercase
      <divider>                  ← gradient lines + ✦
      <level row>                ← Cinzel label + pill badge
      <XP bar>                   ← custom LinearProgress override
      [XP remaining hint]        ← shown when badgeVisible, replaces old chip toggle
      <gold row>                 ← Cinzel label + value; USD shown if present
      [traits section]           ← only if character.traits?.length > 0
        <divider "Cechy">
        <trait pills>            ← flex-wrap, each: "Name value" in pill
      [favour row]               ← only if import.meta.env.VITE_SHOW_FAVOUR === 'true'
    </div>
  </div>
  <div class="bottomBand">       ← burgundy gradient, "— ✦ —"
  </div>
</div>
```

**Feature flag — Favour:**
```js
const showFavour = import.meta.env.VITE_SHOW_FAVOUR === 'true';
```
Rendered only when `true`. Default: hidden.

---

## AppBar (`Home.jsx`)

- Background: `primary.dark` (`#3a0a0a`) with `border-bottom: 1px solid rgba(200,134,10,0.3)`
- Left: `⚔` icon + `LifeRPG` in Cinzel, letter-spacing 3px
- Right: user display name (italic, muted) + styled logout button (bordered icon)
- Loading state: `CircularProgress` in gold/amber colour

---

## Login Page (`Login.jsx` + `Login.module.css`)

- Full-height flex centre on `#1a1008` background
- Radial glow: `rgba(107,26,26,0.15)` centred behind logo
- Logo: `⚔` with drop-shadow, `LifeRPG` in Cinzel 26px, subtitle "Kronika Bohaterów" in Cinzel small
- Decorative divider below logo (gradient lines + `✦`)
- Google sign-in button: burgundy gradient, gold border, Cinzel label "Zaloguj przez Google", italic subtitle "Wejdź do Kroniki"
- Flavour text below button: `"Twoja legenda czeka..."` (very muted)

---

## Edit Dialog (`EditCharacterDialog.jsx`)

- Same card structure: burgundy bands, parchment body, inner frame, corner ornaments
- Header band: "✦ Edycja Postaci ✦"
- Field labels: Cinzel small-caps uppercase
- Field inputs: MUI `Input` with `variant="standard"`, underline styled to `rgba(107,26,26,0.4)`
- Favour row: rendered only when `VITE_SHOW_FAVOUR === 'true'`
- Save/Cancel in bottom band: Save = muted white bordered button; Cancel = text only

---

## Feature Flag Reference

| Variable | Default | Effect |
|---|---|---|
| `VITE_SHOW_FAVOUR` | unset (hidden) | Shows favour emoji row on card and stepper in edit dialog |

Set in `.env.local` or CI environment variables.

---

## Out of Scope

- No changes to Firestore data model
- No changes to auth logic or routing
- No TypeScript migration
- No new MUI components beyond what already exists
- No animation or transition effects
