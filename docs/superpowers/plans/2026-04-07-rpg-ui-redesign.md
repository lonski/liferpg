# RPG UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the full LifeRPG app to a "Burgundy Decree" RPG aesthetic — parchment cards with deep red bands, Cinzel typography, dark app background, and matching Login/Edit dialog.

**Architecture:** A single MUI `createTheme()` in `src/theme.js` provides palette and typography tokens consumed by all components via `ThemeProvider`. Card-specific decorations (bands, inner frame, corner ornaments) live in `Character.module.css`; Login layout in `Login.module.css`. Favour is gated behind `VITE_SHOW_FAVOUR=true`.

**Tech Stack:** React 19, MUI v7, Vite 8, Vitest + React Testing Library, CSS Modules

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `index.html` | Modify | Add Google Fonts link tags (Cinzel + Libre Baskerville) |
| `src/theme.js` | Create | MUI createTheme — palette, typography, component overrides |
| `src/App.jsx` | Modify | Wrap RouterProvider with ThemeProvider |
| `src/App.css` | Modify | Update body background to `#1a1008` |
| `src/components/Character/Character.module.css` | Create | Card structure: bands, inner frame, corner ornaments, dividers, trait pills, XP hint |
| `src/components/Character/Character.jsx` | Modify | RPG card markup + VITE_SHOW_FAVOUR feature flag |
| `src/components/Character/Character.test.jsx` | Modify | Add tests: header text, edit icon placement, XP hint toggle |
| `src/components/Home/Home.jsx` | Modify | Styled AppBar: ⚔ logo, user name, logout button |
| `src/components/Login/Login.module.css` | Create | Full-height centred layout, logo, button, glow |
| `src/components/Login/Login.css` | Delete | Replaced by Login.module.css |
| `src/components/Login/Login.jsx` | Modify | RPG login layout with Cinzel branding |
| `src/components/EditCharacterDialog/EditCharacterDialog.jsx` | Modify | RPG dialog: burgundy bands, Cinzel labels, feature-flagged favour row |

---

## Task 1: Add Google Fonts

**Files:**
- Modify: `index.html`

- [ ] **Step 1: Add font preconnect and stylesheet link**

Replace the existing `<title>` line area in `index.html` — add these two tags inside `<head>`, before the closing `</head>`:

```html
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@400;600;700&family=Libre+Baskerville:ital,wght@0,400;0,700;1,400&display=swap" rel="stylesheet" />
    <title>Liferpg</title>
```

- [ ] **Step 2: Run the dev server briefly to confirm fonts load**

```bash
npm start
```

Open http://localhost:5173 — fonts will load from Google CDN. Stop with Ctrl+C.

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: add Cinzel and Libre Baskerville Google Fonts"
```

---

## Task 2: Create MUI Theme

**Files:**
- Create: `src/theme.js`

- [ ] **Step 1: Write a failing test for theme tokens**

Add to end of `src/App.test.jsx`:

```jsx
import theme from './theme';

test('theme has burgundy primary colour', () => {
  expect(theme.palette.primary.main).toBe('#7a1414');
});

test('theme has dark warm background', () => {
  expect(theme.palette.background.default).toBe('#1a1008');
});

test('theme uses Cinzel for h4 typography', () => {
  expect(theme.typography.h4.fontFamily).toContain('Cinzel');
});
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
npm test -- --reporter=verbose 2>&1 | grep -E "(FAIL|PASS|theme)"
```

Expected: three failures — `Cannot find module './theme'`

- [ ] **Step 3: Create `src/theme.js`**

```js
import { createTheme } from '@mui/material/styles';

const theme = createTheme({
  palette: {
    primary: {
      main: '#7a1414',
      dark: '#3a0a0a',
    },
    background: {
      default: '#1a1008',
      paper: '#e0ccaa',
    },
    text: {
      primary: '#1a0a0a',
    },
  },
  typography: {
    fontFamily: "'Libre Baskerville', Georgia, serif",
    h1: { fontFamily: "'Cinzel', serif" },
    h2: { fontFamily: "'Cinzel', serif" },
    h3: { fontFamily: "'Cinzel', serif" },
    h4: { fontFamily: "'Cinzel', serif" },
    overline: {
      fontFamily: "'Cinzel', serif",
      letterSpacing: '3px',
    },
  },
  components: {
    MuiLinearProgress: {
      styleOverrides: {
        root: {
          backgroundColor: 'rgba(107,26,26,0.12)',
          border: '1px solid rgba(107,26,26,0.35)',
          borderRadius: 2,
          height: 8,
        },
        bar: {
          background: 'linear-gradient(90deg, #6b1a1a, #c8860a)',
          borderRadius: 2,
        },
      },
    },
    MuiChip: {
      styleOverrides: {
        root: {
          fontFamily: "'Libre Baskerville', Georgia, serif",
          color: '#1a0a0a',
          borderColor: 'rgba(107,26,26,0.4)',
        },
      },
    },
    MuiButton: {
      styleOverrides: {
        containedPrimary: {
          background: 'linear-gradient(135deg, #3a0a0a, #6b1a1a)',
          border: '1px solid rgba(200,134,10,0.5)',
          color: '#f5e8d0',
          '&:hover': {
            background: 'linear-gradient(135deg, #4a1010, #8b2020)',
          },
        },
        outlinedPrimary: {
          borderColor: 'rgba(107,26,26,0.5)',
          color: '#1a0a0a',
        },
      },
    },
    MuiDialog: {
      styleOverrides: {
        paper: {
          background: 'transparent',
          boxShadow: 'none',
          overflow: 'visible',
          margin: 16,
        },
      },
    },
    MuiInput: {
      styleOverrides: {
        underline: {
          '&:before': {
            borderBottomColor: 'rgba(107,26,26,0.4)',
          },
          '&:hover:not(.Mui-disabled):before': {
            borderBottomColor: '#7a1414',
          },
        },
      },
    },
  },
});

export default theme;
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
npm test -- --reporter=verbose 2>&1 | grep -E "(FAIL|PASS|theme)"
```

Expected: all three new tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/theme.js src/App.test.jsx
git commit -m "feat: add RPG MUI theme with burgundy palette and Cinzel typography"
```

---

## Task 3: Wire ThemeProvider and Update Background

**Files:**
- Modify: `src/App.jsx`
- Modify: `src/App.css`

- [ ] **Step 1: Run current App test to confirm it passes before changes**

```bash
npm test -- App.test --reporter=verbose
```

Expected: PASS — `renders without crashing`

- [ ] **Step 2: Update `src/App.jsx`**

```jsx
import { Box } from "@mui/material";
import { ThemeProvider } from "@mui/material/styles";
import CssBaseline from "@mui/material/CssBaseline";
import "./App.css";
import { Home } from "./components/Home/Home";
import { Login } from "./components/Login/Login";
import { createBrowserRouter, RouterProvider } from "react-router-dom";
import React from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import theme from "./theme";

const queryClient = new QueryClient();

const router = createBrowserRouter([
  { path: "/", element: <Home /> },
  { path: "/login", element: <Login /> },
]);

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <Box className="app">
          <RouterProvider router={router} />
        </Box>
      </ThemeProvider>
    </QueryClientProvider>
  );
}

export default App;
```

- [ ] **Step 3: Update `src/App.css`**

```css
.App {
  text-align: center;
}

body {
  background-color: #1a1008;
}
```

- [ ] **Step 4: Run App test to confirm it still passes**

```bash
npm test -- App.test --reporter=verbose
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/App.jsx src/App.css
git commit -m "feat: wire ThemeProvider and set dark RPG background"
```

---

## Task 4: Character Card — CSS Module

**Files:**
- Create: `src/components/Character/Character.module.css`

- [ ] **Step 1: Create `src/components/Character/Character.module.css`**

```css
/* ── Outer card ── */
.card {
  background: radial-gradient(ellipse at 50% 0%, #f5e8d0 0%, #e0ccaa 60%, #c8b080 100%);
  border: 2px solid #6b1a1a;
  border-radius: 4px;
  box-shadow: 0 6px 24px rgba(0, 0, 0, 0.6);
  overflow: hidden;
  margin: 8px 0;
}

/* ── Bands ── */
.topBand {
  background: linear-gradient(90deg, #3a0a0a, #7a1414, #3a0a0a);
  padding: 7px 16px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.bandLabel {
  font-family: 'Cinzel', serif;
  font-size: 8px;
  letter-spacing: 4px;
  color: rgba(245, 232, 208, 0.85);
  text-transform: uppercase;
}

.bottomBand {
  background: linear-gradient(90deg, #3a0a0a, #7a1414, #3a0a0a);
  padding: 5px 16px;
  text-align: center;
  color: rgba(245, 232, 208, 0.5);
  font-size: 10px;
  letter-spacing: 3px;
}

/* ── Body / inner frame ── */
.body {
  padding: 16px;
}

.innerFrame {
  position: relative;
  border: 1px solid rgba(107, 26, 26, 0.35);
  border-radius: 2px;
  padding: 12px;
}

.cornerOrnament {
  position: absolute;
  font-size: 12px;
  color: rgba(107, 26, 26, 0.55);
  line-height: 1;
  pointer-events: none;
}

.cornerTL { top: 5px; left: 5px; }
.cornerTR { top: 5px; right: 5px; transform: scaleX(-1); }

/* ── Name / class ── */
.nameBlock {
  text-align: center;
  padding: 0 16px;
  margin-bottom: 4px;
}

.characterName {
  font-family: 'Cinzel', serif !important;
  font-size: 22px !important;
  font-weight: 700 !important;
  color: #2d0a0a !important;
  letter-spacing: 2px !important;
}

.characterClass {
  font-family: 'Cinzel', serif !important;
  font-size: 9px !important;
  letter-spacing: 4px !important;
  color: #6b1a1a !important;
  text-transform: uppercase !important;
  margin-top: 3px !important;
  display: block !important;
}

/* ── Divider ── */
.divider {
  display: flex;
  align-items: center;
  gap: 6px;
  margin: 10px 0;
}

.dividerLine {
  flex: 1;
  height: 1px;
}

.dividerLineLeft {
  background: linear-gradient(90deg, transparent, #6b1a1a);
}

.dividerLineRight {
  background: linear-gradient(90deg, #6b1a1a, transparent);
}

.dividerGlyph {
  font-size: 11px;
  color: #6b1a1a;
}

/* ── Level row ── */
.levelRow {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.statLabel {
  font-family: 'Cinzel', serif;
  font-size: 10px;
  letter-spacing: 2px;
  color: #6b1a1a;
  text-transform: uppercase;
}

.levelBadge {
  font-family: 'Cinzel', serif;
  font-size: 15px;
  font-weight: 700;
  color: #2d0a0a;
  background: rgba(107, 26, 26, 0.1);
  border: 1px solid rgba(107, 26, 26, 0.4);
  border-radius: 3px;
  padding: 1px 12px;
}

/* ── XP bar ── */
.xpMeta {
  display: flex;
  justify-content: space-between;
  font-size: 10px;
  color: #6b1a1a;
  font-style: italic;
  margin-bottom: 4px;
}

.xpBarWrapper {
  margin-bottom: 4px;
  cursor: pointer;
}

.xpHint {
  text-align: center;
  margin-top: 4px;
  font-size: 10px;
  color: #6b1a1a;
  font-style: italic;
  background: rgba(107, 26, 26, 0.08);
  border: 1px solid rgba(107, 26, 26, 0.2);
  border-radius: 10px;
  padding: 2px 10px;
  display: inline-block;
}

.xpSection {
  margin-bottom: 10px;
}

/* ── Gold row ── */
.goldRow {
  text-align: center;
  margin-bottom: 10px;
}

.goldValue {
  font-size: 13px;
  font-weight: 700;
  color: #2d0a0a;
}

.goldSeparator {
  color: #6b1a1a;
  margin: 0 8px;
}

/* ── Traits ── */
.traitsDivider {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 8px;
}

.traitsDividerLineLeft {
  flex: 1;
  height: 1px;
  background: linear-gradient(90deg, transparent, rgba(107, 26, 26, 0.4));
}

.traitsDividerLineRight {
  flex: 1;
  height: 1px;
  background: linear-gradient(90deg, rgba(107, 26, 26, 0.4), transparent);
}

.traitsDividerLabel {
  font-family: 'Cinzel', serif;
  font-size: 8px;
  letter-spacing: 3px;
  color: #6b1a1a;
  text-transform: uppercase;
}

.traitPills {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
  justify-content: center;
}

.traitPill {
  background: rgba(107, 26, 26, 0.1);
  border: 1px solid rgba(107, 26, 26, 0.4);
  border-radius: 10px;
  padding: 2px 10px;
  font-size: 10px;
  color: #2d0a0a;
}

.traitName {
  color: #6b1a1a;
  font-style: italic;
}

.traitValue {
  font-weight: 700;
  margin-left: 4px;
}

/* ── Edit icon in band ── */
.editIconBtn {
  color: rgba(245, 232, 208, 0.55) !important;
  padding: 2px !important;
}

.editIconBtn:hover {
  color: rgba(245, 232, 208, 0.9) !important;
}
```

- [ ] **Step 2: Run existing Character tests to confirm they still pass**

```bash
npm test -- Character.test --reporter=verbose
```

Expected: all 4 tests PASS (nothing in the component has changed yet)

- [ ] **Step 3: Commit**

```bash
git add src/components/Character/Character.module.css
git commit -m "feat: add RPG character card CSS module"
```

---

## Task 5: Refactor Character.jsx

**Files:**
- Modify: `src/components/Character/Character.jsx`
- Modify: `src/components/Character/Character.test.jsx`

- [ ] **Step 1: Add new tests to `Character.test.jsx`**

Add these tests after the existing ones:

```jsx
test('card header shows "Karta Postaci"', () => {
  render(<Character character={{ name: 'Hero', favour: 0 }} user={null} />);
  expect(screen.getByText('✦ Karta Postaci ✦')).toBeInTheDocument();
});

test('edit button is not visible to non-admin users', () => {
  render(<Character character={{ name: 'Hero', favour: 0 }} user={{ admin: false }} />);
  expect(screen.queryByLabelText('edytuj postać')).not.toBeInTheDocument();
});

test('edit button is visible to admin users', () => {
  render(<Character character={{ name: 'Hero', favour: 0 }} user={{ admin: true }} />);
  expect(screen.getByLabelText('edytuj postać')).toBeInTheDocument();
});

test('clicking XP bar shows remaining XP hint', () => {
  const character = { name: 'Hero', favour: 0, level: 5, current_xp: 300, next_level_xp: 500 };
  render(<Character character={character} user={null} />);
  const xpBar = screen.getByRole('progressbar');
  fireEvent.click(xpBar);
  expect(screen.getByText(/200/)).toBeInTheDocument();
});
```

Also add `fireEvent` to the import at the top:

```jsx
import { render, screen, fireEvent } from '@testing-library/react';
```

- [ ] **Step 2: Run new tests to confirm they fail**

```bash
npm test -- Character.test --reporter=verbose
```

Expected: 4 new tests FAIL (old 4 still PASS)

- [ ] **Step 3: Rewrite `src/components/Character/Character.jsx`**

```jsx
import React, { useState } from "react";
import { IconButton, LinearProgress } from "@mui/material";
import EditIcon from "@mui/icons-material/Edit";
import { EditCharacterDialog } from "components/EditCharacterDialog/EditCharacterDialog";
import PropTypes from "prop-types";
import styles from "./Character.module.css";

const showFavour = import.meta.env.VITE_SHOW_FAVOUR === 'true';

const FavourEmoji = ({ favour }) => {
  if (favour < -1) return <span>😠</span>;
  if (favour === -1) return <span>😕</span>;
  if (favour > 0) return <span>😊</span>;
  return <span>😐</span>;
};

FavourEmoji.propTypes = { favour: PropTypes.number };

export const Character = ({ character, user }) => {
  const [edit, setEdit] = useState(false);
  const [badgeVisible, setBadgeVisible] = useState(false);

  if (!character) return null;

  const favour = character?.favour ?? 0;
  const xpPercent = character.level != null
    ? Math.min((character.current_xp * 100) / character.next_level_xp, 100)
    : 0;
  const xpRemaining = character.next_level_xp - character.current_xp;

  return (
    <div className={styles.card}>
      {/* Top band */}
      <div className={styles.topBand}>
        <span className={styles.bandLabel}>✦ Karta Postaci ✦</span>
        {user?.admin && (
          <IconButton
            aria-label="edytuj postać"
            size="small"
            className={styles.editIconBtn}
            onClick={() => setEdit(true)}
          >
            <EditIcon fontSize="small" />
          </IconButton>
        )}
      </div>

      {/* Body */}
      <div className={styles.body}>
        <div className={styles.innerFrame}>
          <span className={`${styles.cornerOrnament} ${styles.cornerTL}`}>❧</span>
          <span className={`${styles.cornerOrnament} ${styles.cornerTR}`}>❧</span>

          {/* Name + class */}
          <div className={styles.nameBlock}>
            <span className={styles.characterName}>{character.name}</span>
            {character.clazz && (
              <span className={styles.characterClass}>{character.clazz}</span>
            )}
          </div>

          {/* Divider */}
          <div className={styles.divider}>
            <span className={`${styles.dividerLine} ${styles.dividerLineLeft}`} />
            <span className={styles.dividerGlyph}>✦</span>
            <span className={`${styles.dividerLine} ${styles.dividerLineRight}`} />
          </div>

          {/* Level + XP */}
          {character.level != null && (
            <>
              <div className={styles.levelRow}>
                <span className={styles.statLabel}>Poziom</span>
                <span className={styles.levelBadge}>{character.level}</span>
              </div>
              <div className={styles.xpSection}>
                <div className={styles.xpMeta}>
                  <span>Doświadczenie</span>
                  <span>{character.current_xp} / {character.next_level_xp} XP</span>
                </div>
                <div
                  className={styles.xpBarWrapper}
                  onClick={() => setBadgeVisible((prev) => !prev)}
                >
                  <LinearProgress variant="determinate" value={xpPercent} />
                </div>
                {badgeVisible && (
                  <div style={{ textAlign: 'center' }}>
                    <span className={styles.xpHint}>
                      Do następnego poziomu: <strong>{xpRemaining}</strong> XP
                    </span>
                  </div>
                )}
              </div>
            </>
          )}

          {/* Gold */}
          {character.gold && (
            <div className={styles.goldRow}>
              <span className={styles.statLabel}>Złoto&nbsp; </span>
              <span className={styles.goldValue}>{character.gold} zł</span>
              {character.gold_usd != null && (
                <>
                  <span className={styles.goldSeparator}>·</span>
                  <span className={styles.goldValue}>{character.gold_usd} $</span>
                </>
              )}
            </div>
          )}

          {/* Favour (feature-flagged) */}
          {showFavour && (
            <div style={{ textAlign: 'center', marginBottom: 8 }}>
              <FavourEmoji favour={favour} />
            </div>
          )}

          {/* Traits */}
          {character.traits?.length > 0 && (
            <>
              <div className={styles.traitsDivider}>
                <span className={styles.traitsDividerLineLeft} />
                <span className={styles.traitsDividerLabel}>Cechy</span>
                <span className={styles.traitsDividerLineRight} />
              </div>
              <div className={styles.traitPills}>
                {character.traits.map((trait, index) => (
                  <div key={index} className={styles.traitPill}>
                    <span className={styles.traitName}>{trait.name}</span>
                    <span className={styles.traitValue}>{trait.value}</span>
                  </div>
                ))}
              </div>
            </>
          )}
        </div>
      </div>

      {/* Bottom band */}
      <div className={styles.bottomBand}>— ✦ —</div>

      {/* Edit dialog */}
      {user?.admin && (
        <EditCharacterDialog
          charToEdit={character}
          open={edit}
          handleClose={() => setEdit(false)}
        />
      )}
    </div>
  );
};

Character.propTypes = {
  character: PropTypes.object,
  user: PropTypes.object,
};
```

- [ ] **Step 4: Run all Character tests**

```bash
npm test -- Character.test --reporter=verbose
```

Expected: all 8 tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/components/Character/Character.jsx src/components/Character/Character.test.jsx
git commit -m "feat: apply RPG card design to Character component"
```

---

## Task 6: Style AppBar in Home.jsx

**Files:**
- Modify: `src/components/Home/Home.jsx`

- [ ] **Step 1: Rewrite `src/components/Home/Home.jsx`**

```jsx
import {
  AppBar,
  Box,
  CircularProgress,
  Container,
  IconButton,
  Toolbar,
  Typography,
} from "@mui/material";
import LogoutIcon from "@mui/icons-material/Logout";
import React from "react";
import { useNavigate } from "react-router-dom";
import { logout } from "../../firebase";
import { Character } from "components/Character/Character";
import { useCharacters } from "hooks/useCharacters";

export const Home = () => {
  const navigate = useNavigate();
  const handleLogout = () => {
    logout().then(() => navigate("/login"));
  };
  const [characters, loading, user] = useCharacters();

  return (
    <>
      <AppBar
        position="static"
        sx={{
          background: 'linear-gradient(90deg, #280606, #4a0e0e, #280606)',
          borderBottom: '1px solid rgba(200,134,10,0.3)',
          boxShadow: '0 2px 12px rgba(0,0,0,0.6)',
        }}
      >
        <Toolbar variant="dense">
          <Typography
            variant="h6"
            sx={{
              fontFamily: "'Cinzel', serif",
              fontWeight: 700,
              letterSpacing: '3px',
              color: '#f5e8d0',
              flexGrow: 1,
            }}
          >
            ⚔&nbsp; LifeRPG
          </Typography>

          {loading ? (
            <CircularProgress size={20} sx={{ color: '#c8860a' }} />
          ) : (
            <>
              {user?.displayName && (
                <Typography
                  variant="body2"
                  sx={{
                    color: 'rgba(245,232,208,0.45)',
                    fontStyle: 'italic',
                    mr: 1,
                    fontSize: '11px',
                  }}
                >
                  {user.displayName}
                </Typography>
              )}
              <IconButton
                onClick={handleLogout}
                size="small"
                sx={{
                  color: 'rgba(245,232,208,0.6)',
                  border: '1px solid rgba(200,134,10,0.4)',
                  borderRadius: '3px',
                  padding: '4px 6px',
                  '&:hover': { color: '#f5e8d0', borderColor: 'rgba(200,134,10,0.8)' },
                }}
              >
                <LogoutIcon fontSize="small" />
              </IconButton>
            </>
          )}
        </Toolbar>
      </AppBar>

      <Container maxWidth="xs" sx={{ py: 2 }}>
        {characters &&
          characters
            .filter((c) => c !== undefined)
            .map((c) => <Character key={c.id} character={c} user={user} />)}
      </Container>
    </>
  );
};
```

- [ ] **Step 2: Run all tests to confirm nothing broke**

```bash
npm test -- --reporter=verbose
```

Expected: all tests PASS

- [ ] **Step 3: Commit**

```bash
git add src/components/Home/Home.jsx
git commit -m "feat: apply RPG styling to AppBar"
```

---

## Task 7: Style Login Page

**Files:**
- Create: `src/components/Login/Login.module.css`
- Modify: `src/components/Login/Login.jsx`
- Delete: `src/components/Login/Login.css`

- [ ] **Step 1: Create `src/components/Login/Login.module.css`**

```css
.container {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: #1a1008;
  position: relative;
}

.container::before {
  content: '';
  position: absolute;
  inset: 0;
  background: radial-gradient(ellipse at 50% 40%, rgba(107, 26, 26, 0.15) 0%, transparent 70%);
  pointer-events: none;
}

.logoMark {
  text-align: center;
  margin-bottom: 32px;
  position: relative;
  z-index: 1;
}

.swordIcon {
  font-size: 40px;
  display: block;
  margin-bottom: 10px;
  filter: drop-shadow(0 0 12px rgba(200, 134, 10, 0.4));
}

.title {
  font-family: 'Cinzel', serif !important;
  font-size: 28px !important;
  font-weight: 700 !important;
  color: #f5e8d0 !important;
  letter-spacing: 4px !important;
  text-shadow: 0 0 20px rgba(200, 134, 10, 0.3);
}

.subtitle {
  font-family: 'Cinzel', serif;
  font-size: 9px;
  letter-spacing: 5px;
  color: rgba(200, 134, 10, 0.7);
  text-transform: uppercase;
  margin-top: 4px;
  display: block;
}

.divider {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 12px;
}

.dividerLine {
  flex: 1;
  height: 1px;
  width: 60px;
}

.dividerLineLeft {
  background: linear-gradient(90deg, transparent, rgba(200, 134, 10, 0.4));
}

.dividerLineRight {
  background: linear-gradient(90deg, rgba(200, 134, 10, 0.4), transparent);
}

.dividerGlyph {
  font-size: 11px;
  color: rgba(200, 134, 10, 0.5);
}

.loginButton {
  background: linear-gradient(135deg, #3a0a0a, #6b1a1a) !important;
  border: 1px solid rgba(200, 134, 10, 0.5) !important;
  border-radius: 4px !important;
  padding: 12px 28px !important;
  cursor: pointer;
  position: relative;
  z-index: 1;
  text-transform: none !important;
  display: flex !important;
  align-items: center !important;
  gap: 12px !important;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5) !important;
}

.loginButton:hover {
  background: linear-gradient(135deg, #4a1010, #8b2020) !important;
  border-color: rgba(200, 134, 10, 0.8) !important;
}

.loginButtonLabel {
  font-family: 'Cinzel', serif;
  font-size: 11px;
  letter-spacing: 3px;
  color: #f5e8d0;
  text-transform: uppercase;
  display: block;
}

.loginButtonSub {
  font-size: 9px;
  color: rgba(245, 232, 208, 0.45);
  font-style: italic;
  display: block;
  margin-top: 1px;
}

.flavourText {
  margin-top: 20px;
  font-size: 9px;
  color: rgba(245, 232, 208, 0.2);
  font-style: italic;
  letter-spacing: 1px;
  position: relative;
  z-index: 1;
}
```

- [ ] **Step 2: Rewrite `src/components/Login/Login.jsx`**

```jsx
import React, { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { auth, signInWithGoogle } from "../../firebase";
import { useAuthState } from "react-firebase-hooks/auth";
import { Button } from "@mui/material";
import styles from "./Login.module.css";

export const Login = () => {
  const [user, loading] = useAuthState(auth);
  const navigate = useNavigate();

  useEffect(() => {
    if (loading) return;
    if (user) navigate("/");
  }, [user, loading, navigate]);

  return (
    <div className={styles.container}>
      <div className={styles.logoMark}>
        <span className={styles.swordIcon}>⚔</span>
        <span className={styles.title}>LifeRPG</span>
        <span className={styles.subtitle}>Kronika Bohaterów</span>
        <div className={styles.divider}>
          <span className={`${styles.dividerLine} ${styles.dividerLineLeft}`} />
          <span className={styles.dividerGlyph}>✦</span>
          <span className={`${styles.dividerLine} ${styles.dividerLineRight}`} />
        </div>
      </div>

      <Button
        variant="contained"
        onClick={signInWithGoogle}
        className={styles.loginButton}
        disableElevation
      >
        <span style={{ fontSize: 20 }}>G</span>
        <span>
          <span className={styles.loginButtonLabel}>Zaloguj przez Google</span>
          <span className={styles.loginButtonSub}>Wejdź do Kroniki</span>
        </span>
      </Button>

      <p className={styles.flavourText}>&ldquo;Twoja legenda czeka...&rdquo;</p>
    </div>
  );
};
```

- [ ] **Step 3: Delete old `Login.css`**

```bash
rm src/components/Login/Login.css
```

- [ ] **Step 4: Run all tests**

```bash
npm test -- --reporter=verbose
```

Expected: all tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/components/Login/Login.jsx src/components/Login/Login.module.css
git rm src/components/Login/Login.css
git commit -m "feat: apply RPG styling to Login page"
```

---

## Task 8: Style Edit Character Dialog

**Files:**
- Modify: `src/components/EditCharacterDialog/EditCharacterDialog.jsx`

- [ ] **Step 1: Run EditCharacterDialog tests to confirm current state**

```bash
npm test -- EditCharacterDialog.test --reporter=verbose
```

Expected: all 5 tests PASS

- [ ] **Step 2: Rewrite `src/components/EditCharacterDialog/EditCharacterDialog.jsx`**

```jsx
import {
  Autocomplete,
  Box,
  Button,
  Dialog,
  IconButton,
  Input,
  TextField,
  Typography,
} from "@mui/material";
import DeleteIcon from "@mui/icons-material/Delete";
import AddIcon from "@mui/icons-material/Add";
import React, { useEffect, useMemo, useState } from "react";
import PropTypes from "prop-types";
import { doc, updateDoc } from "firebase/firestore";
import { db } from "../../firebase";
import { useQueryClient } from "@tanstack/react-query";

const showFavour = import.meta.env.VITE_SHOW_FAVOUR === 'true';

const bandStyle = {
  background: 'linear-gradient(90deg, #3a0a0a, #7a1414, #3a0a0a)',
  padding: '7px 16px',
  textAlign: 'center',
};

const bandLabelStyle = {
  fontFamily: "'Cinzel', serif",
  fontSize: '8px',
  letterSpacing: '4px',
  color: 'rgba(245,232,208,0.85)',
  textTransform: 'uppercase',
};

const fieldLabelStyle = {
  fontFamily: "'Cinzel', serif",
  fontSize: '9px',
  letterSpacing: '2px',
  color: '#6b1a1a',
  textTransform: 'uppercase',
  minWidth: 90,
};

const inputSx = {
  width: 64,
  '& .MuiInput-underline:before': { borderBottomColor: 'rgba(107,26,26,0.4)' },
};

export const EditCharacterDialog = ({ charToEdit, open, handleClose }) => {
  const queryClient = useQueryClient();
  const allCharacters = queryClient
    .getQueriesData({ queryKey: ["characters"] })
    .flatMap(([, data]) => (data || []));
  const existingTraitNames = useMemo(
    () => [...new Set(allCharacters.flatMap((c) => (c.traits || []).map((t) => t.name)))],
    [open] // eslint-disable-line
  );
  const [character, setCharacter] = useState(charToEdit);
  useEffect(() => {
    if (open) setCharacter(charToEdit);
  }, [open, charToEdit]);
  const [newTraitName, setNewTraitName] = useState('');
  const [newTraitValue, setNewTraitValue] = useState('');

  const handleSave = async () => {
    try {
      const charDoc = doc(db, "characters", character.id);
      await updateDoc(charDoc, character);
      await queryClient.invalidateQueries({ queryKey: ["characters"] });
      handleClose();
    } catch (err) {
      console.error(err);
      alert(err.message);
    }
  };

  if (!character) return null;

  return (
    <Dialog
      onClose={handleClose}
      open={open}
      PaperProps={{
        sx: {
          background: 'transparent',
          boxShadow: 'none',
          overflow: 'visible',
          m: 2,
        },
      }}
    >
      {/* Card wrapper */}
      <Box
        sx={{
          background: 'radial-gradient(ellipse at 50% 0%, #f5e8d0 0%, #e0ccaa 60%, #c8b080 100%)',
          border: '2px solid #6b1a1a',
          borderRadius: '4px',
          overflow: 'hidden',
          boxShadow: '0 8px 32px rgba(0,0,0,0.7)',
          minWidth: 280,
        }}
      >
        {/* Top band */}
        <Box sx={bandStyle}>
          <span style={bandLabelStyle}>✦ Edycja Postaci ✦</span>
        </Box>

        {/* Body */}
        <Box sx={{ p: 2 }}>
          <Box
            sx={{
              position: 'relative',
              border: '1px solid rgba(107,26,26,0.35)',
              borderRadius: '2px',
              p: '12px',
            }}
          >
            {/* Corner ornaments */}
            <Box component="span" sx={{ position: 'absolute', top: 5, left: 5, fontSize: 12, color: 'rgba(107,26,26,0.55)', lineHeight: 1, pointerEvents: 'none' }}>❧</Box>
            <Box component="span" sx={{ position: 'absolute', top: 5, right: 5, fontSize: 12, color: 'rgba(107,26,26,0.55)', lineHeight: 1, transform: 'scaleX(-1)', pointerEvents: 'none' }}>❧</Box>

            {/* Character name */}
            <Typography sx={{ fontFamily: "'Cinzel',serif", fontSize: 16, fontWeight: 700, color: '#2d0a0a', letterSpacing: 2, textAlign: 'center', mb: 1.5 }}>
              {character.name}
            </Typography>

            {/* Numeric fields */}
            {[
              { label: 'Poziom', key: 'level' },
              { label: 'Złoto', key: 'gold' },
              { label: 'Dolary', key: 'gold_usd' },
            ].map(({ label, key }) => (
              <Box key={key} display="flex" justifyContent="space-between" alignItems="center" sx={{ mb: 1 }}>
                <Typography sx={fieldLabelStyle}>{label}</Typography>
                <Input
                  type="number"
                  value={character[key]}
                  onChange={(e) => setCharacter((prev) => ({ ...prev, [key]: Number(e.target.value) }))}
                  sx={inputSx}
                />
              </Box>
            ))}

            {/* XP row (two inputs) */}
            <Box display="flex" justifyContent="space-between" alignItems="center" sx={{ mb: 1 }}>
              <Typography sx={fieldLabelStyle}>XP</Typography>
              <Box display="flex" alignItems="center" gap={0.5}>
                <Input
                  type="number"
                  value={character.current_xp}
                  onChange={(e) => setCharacter((prev) => ({ ...prev, current_xp: Number(e.target.value) }))}
                  sx={inputSx}
                />
                <Typography sx={{ color: '#6b1a1a', mx: 0.5 }}>/</Typography>
                <Input
                  type="number"
                  value={character.next_level_xp}
                  onChange={(e) => setCharacter((prev) => ({ ...prev, next_level_xp: Number(e.target.value) }))}
                  sx={inputSx}
                />
              </Box>
            </Box>

            {/* Favour (feature-flagged) */}
            {showFavour && (
              <Box display="flex" justifyContent="space-between" alignItems="center" sx={{ mb: 1 }}>
                <Typography sx={fieldLabelStyle}>Przychylność</Typography>
                <Box display="flex" alignItems="center" gap={1}>
                  <Button size="small" onClick={() => setCharacter((prev) => ({ ...prev, favour: prev.favour - 1 }))}>👎</Button>
                  <Typography sx={{ fontWeight: 700, color: '#2d0a0a' }}>{character.favour}</Typography>
                  <Button size="small" onClick={() => setCharacter((prev) => ({ ...prev, favour: prev.favour + 1 }))}>👍</Button>
                </Box>
              </Box>
            )}

            {/* Traits divider */}
            <Box display="flex" alignItems="center" gap={0.75} sx={{ my: 1.5 }}>
              <Box sx={{ flex: 1, height: 1, background: 'linear-gradient(90deg, transparent, rgba(107,26,26,0.4))' }} />
              <Typography sx={{ fontFamily: "'Cinzel',serif", fontSize: 8, letterSpacing: 3, color: '#6b1a1a', textTransform: 'uppercase' }}>Cechy</Typography>
              <Box sx={{ flex: 1, height: 1, background: 'linear-gradient(90deg, rgba(107,26,26,0.4), transparent)' }} />
            </Box>

            {/* Existing traits */}
            {(character.traits || []).map((trait, index) => (
              <Box key={index} display="flex" alignItems="center" justifyContent="space-between" sx={{ mb: 0.5 }}>
                <Typography sx={{ flex: 1, fontSize: 11, color: '#3d1010', fontStyle: 'italic' }}>{trait.name}</Typography>
                <Input
                  value={trait.value}
                  onChange={(e) => {
                    const value = e.target.value;
                    setCharacter((prev) => ({
                      ...prev,
                      traits: prev.traits.map((t, i) => i === index ? { ...t, value } : t),
                    }));
                  }}
                  sx={{ width: 64 }}
                />
                <IconButton
                  aria-label="usuń cechę"
                  size="small"
                  onClick={() => setCharacter((prev) => ({ ...prev, traits: prev.traits.filter((_, i) => i !== index) }))}
                  sx={{ color: '#6b1a1a', ml: 0.5 }}
                >
                  <DeleteIcon fontSize="small" />
                </IconButton>
              </Box>
            ))}

            {/* Add new trait */}
            <Box display="flex" alignItems="flex-end" gap={1} sx={{ mt: 1 }}>
              <Autocomplete
                freeSolo
                options={existingTraitNames}
                value={newTraitName}
                onChange={(e, value) => setNewTraitName(value || '')}
                onInputChange={(e, value) => setNewTraitName(value || '')}
                renderInput={(params) => (
                  <TextField {...params} variant="standard" placeholder="Nowa cecha..." size="small" />
                )}
                size="small"
                sx={{ flex: 1 }}
              />
              <Input
                value={newTraitValue}
                onChange={(e) => setNewTraitValue(e.target.value)}
                placeholder="Wartość"
                sx={{ width: 64 }}
              />
              <IconButton
                aria-label="dodaj cechę"
                size="small"
                disabled={!newTraitName.trim()}
                onClick={() => {
                  setCharacter((prev) => ({
                    ...prev,
                    traits: [...(prev.traits || []), { name: newTraitName.trim(), value: newTraitValue }],
                  }));
                  setNewTraitName('');
                  setNewTraitValue('');
                }}
                sx={{ color: '#6b1a1a' }}
              >
                <AddIcon fontSize="small" />
              </IconButton>
            </Box>
          </Box>
        </Box>

        {/* Bottom band with Save / Cancel */}
        <Box sx={{ ...bandStyle, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Button
            onClick={handleSave}
            size="small"
            sx={{
              fontFamily: "'Cinzel',serif",
              fontSize: 9,
              letterSpacing: 2,
              color: '#f5e8d0',
              textTransform: 'uppercase',
              border: '1px solid rgba(245,232,208,0.3)',
              borderRadius: '3px',
              px: 2,
              '&:hover': { background: 'rgba(245,232,208,0.1)' },
            }}
          >
            Zapisz
          </Button>
          <Button
            onClick={handleClose}
            size="small"
            sx={{
              fontFamily: "'Cinzel',serif",
              fontSize: 9,
              letterSpacing: 2,
              color: 'rgba(245,232,208,0.5)',
              textTransform: 'uppercase',
              '&:hover': { color: '#f5e8d0' },
            }}
          >
            Anuluj
          </Button>
        </Box>
      </Box>
    </Dialog>
  );
};

EditCharacterDialog.propTypes = {
  charToEdit: PropTypes.object,
  open: PropTypes.bool,
  handleClose: PropTypes.func,
};
```

- [ ] **Step 3: Run EditCharacterDialog tests**

```bash
npm test -- EditCharacterDialog.test --reporter=verbose
```

Expected: all 5 tests PASS

- [ ] **Step 4: Run full test suite**

```bash
npm test -- --reporter=verbose
```

Expected: all tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/components/EditCharacterDialog/EditCharacterDialog.jsx
git commit -m "feat: apply RPG styling to EditCharacterDialog"
```

---

## Task 9: Final Verification

- [ ] **Step 1: Run full test suite**

```bash
npm test -- --reporter=verbose
```

Expected: all tests PASS. Note any failures and fix before proceeding.

- [ ] **Step 2: Build for production**

```bash
npm run build
```

Expected: exits 0, `dist/` created, no errors.

- [ ] **Step 3: Preview production build**

```bash
npm run preview
```

Open http://localhost:4173. Verify:
- Dark `#1a1008` background
- Cards show parchment + burgundy bands
- Cinzel font on character names and AppBar title
- XP bar is burgundy-to-gold gradient
- Login page shows ⚔ LifeRPG + "Kronika Bohaterów"

Stop with Ctrl+C.

- [ ] **Step 4: Final commit if any lint fixes needed**

```bash
npx eslint src/ --fix
git add -p
git commit -m "chore: fix any lint issues after RPG UI redesign"
```

If no issues, skip this step.
