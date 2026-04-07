# Favour Feature Flag Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide the favour (Przychylność) UI behind a `VITE_FEATURE_FAVOUR` env var, disabled by default.

**Architecture:** A single `src/featureFlags.js` module exports the flag. `Character.jsx` and `EditCharacterDialog.jsx` import it and conditionally render favour-related UI. The `.env` file sets the default to `false`.

**Tech Stack:** React 19, Vite 8 (`import.meta.env`), Vitest

---

### Task 1: Add env var and feature flags module

**Files:**
- Create: `.env`
- Create: `src/featureFlags.js`

- [ ] **Step 1: Create `.env`**

```
VITE_FEATURE_FAVOUR=false
```

- [ ] **Step 2: Create `src/featureFlags.js`**

```js
export const FEATURE_FAVOUR = import.meta.env.VITE_FEATURE_FAVOUR === 'true';
```

- [ ] **Step 3: Commit**

```bash
git add .env src/featureFlags.js
git commit -m "feat: add VITE_FEATURE_FAVOUR feature flag"
```

---

### Task 2: Hide favour in Character.jsx

**Files:**
- Modify: `src/components/Character/Character.jsx`
- Test: `src/components/Character/Character.test.jsx`

- [ ] **Step 1: Write failing test**

Add to `src/components/Character/Character.test.jsx`:

```js
test('does not render favour icon by default (flag off)', () => {
  render(<Character character={{ name: 'Hero', favour: 1 }} user={null} />);
  // SentimentSatisfiedAltIcon has aria role "img" with title; absence means flag is off
  expect(document.querySelector('[data-testid="SentimentSatisfiedAltIcon"]')).not.toBeInTheDocument();
});
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
npm test -- --reporter=verbose Character.test
```

Expected: FAIL — the icon is rendered because the flag guard isn't in place yet.

- [ ] **Step 3: Update Character.jsx**

Add import at top of `src/components/Character/Character.jsx` (after existing imports):

```js
import { FEATURE_FAVOUR } from "featureFlags";
```

Wrap the favour emoji block (the inner `Box` that renders Sentiment icons, currently lines ~34–46) with the flag:

```jsx
{FEATURE_FAVOUR && (
  <Box marginTop={"10px"} display="flex" justifyContent="left">
    {favour === 0 && <SentimentSatisfiedIcon />}
    {favour === -1 && (
      <SentimentDissatisfied color="warning" />
    )}
    {favour < -1 && (
      <SentimentVeryDissatisfiedIcon color="error" />
    )}
    {favour > 0 && (
      <SentimentSatisfiedAltIcon color="success" />
    )}
  </Box>
)}
```

The outer `Box display="flex" justifyContent="space-between"` that wraps both the character name and this favour Box should remain. Only the inner favour `Box` gets the flag guard.

- [ ] **Step 4: Run all tests**

```bash
npm test
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add src/components/Character/Character.jsx src/components/Character/Character.test.jsx
git commit -m "feat: hide favour icon behind VITE_FEATURE_FAVOUR flag"
```

---

### Task 3: Hide favour in EditCharacterDialog.jsx

**Files:**
- Modify: `src/components/EditCharacterDialog/EditCharacterDialog.jsx`
- Test: `src/components/EditCharacterDialog/EditCharacterDialog.test.jsx`

- [ ] **Step 1: Read existing test file to understand setup**

Read `src/components/EditCharacterDialog/EditCharacterDialog.test.jsx` to understand mock patterns before writing the test.

- [ ] **Step 2: Write failing test**

Add to `src/components/EditCharacterDialog/EditCharacterDialog.test.jsx`:

```js
test('does not render Przychylność field by default (flag off)', () => {
  // render with open=true and a character that has favour
  const char = { id: '1', level: 1, current_xp: 0, next_level_xp: 100, gold: 0, gold_usd: 0, favour: 2, traits: [] };
  render(<EditCharacterDialog charToEdit={char} open={true} handleClose={() => {}} />);
  expect(screen.queryByText('Przychylność:')).not.toBeInTheDocument();
});
```

- [ ] **Step 3: Run test to confirm it fails**

```bash
npm test -- --reporter=verbose EditCharacterDialog.test
```

Expected: FAIL — Przychylność is rendered regardless of flag.

- [ ] **Step 4: Update EditCharacterDialog.jsx**

Add import at top of `src/components/EditCharacterDialog/EditCharacterDialog.jsx` (after existing imports):

```js
import { FEATURE_FAVOUR } from "../../featureFlags";
```

Wrap the entire Przychylność `Box` (the one containing the label "Przychylność:" and the +/- buttons) with the flag:

```jsx
{FEATURE_FAVOUR && (
  <Box
    display="flex"
    justifyContent="space-between"
    alignItems={"center"}
  >
    <Box sx={{ width: "90px" }}>
      <Typography color={"black"} sx={{ marginLeft: "4px" }}>
        Przychylność:
      </Typography>
    </Box>
    <Box>
      <Box
        sx={{ marginLeft: "4px" }}
        display="flex"
        justifyContent="space-between"
        alignItems="center"
      >
        <Button
          onClick={() => {
            setCharacter((prev) => ({
              ...prev,
              favour: prev.favour - 1,
            }));
          }}
        >
          &#x1f44e;
        </Button>
        <Box>{character.favour}</Box>
        <Button
          onClick={() => {
            setCharacter((prev) => ({
              ...prev,
              favour: prev.favour + 1,
            }));
          }}
        >
          &#128077;
        </Button>
      </Box>
    </Box>
  </Box>
)}
```

- [ ] **Step 5: Run all tests**

```bash
npm test
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add src/components/EditCharacterDialog/EditCharacterDialog.jsx src/components/EditCharacterDialog/EditCharacterDialog.test.jsx
git commit -m "feat: hide favour editor field behind VITE_FEATURE_FAVOUR flag"
```
