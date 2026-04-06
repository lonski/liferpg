# CRA → Vite + Vitest Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Create React App (`react-scripts`) with Vite for bundling and Vitest for testing, eliminating all deprecated CRA dependencies and compatibility workarounds.

**Architecture:** Vite replaces webpack with a native-ESM dev server and Rollup-based production build. Vitest runs inside Vite's pipeline so the same config (aliases, plugins) applies to tests automatically, removing the need for the `moduleNameMapper` and `TextEncoder` polyfill added during the dependency upgrade. ESLint stays on v8 (extracted from `package.json` to `.eslintrc.json`; v9 upgrade deferred until `eslint-config-standard` publishes a compatible release).

**Tech Stack:** Vite 6, @vitejs/plugin-react, Vitest, jsdom, @testing-library/* (unchanged)

---

## File map

| Action | Path |
|--------|------|
| Create | `vite.config.js` |
| Create | `index.html` (root) |
| Create | `.eslintrc.json` |
| Modify | `package.json` |
| Modify | `src/setupTests.js` |
| Rename | `src/index.js` → `src/main.jsx` |
| Modify | `src/components/Character/Character.test.jsx` |
| Modify | `src/components/EditCharacterDialog/EditCharacterDialog.test.jsx` |
| Delete | `public/index.html` |
| Delete | `src/reportWebVitals.js` |

---

### Task 1: Swap dependencies

**Files:**
- Modify: `package.json`

- [ ] **Step 1: Install Vite and Vitest packages**

```bash
npm install --save-dev vite @vitejs/plugin-react vitest @vitest/coverage-v8 jsdom
```

Expected: packages added, no peer dependency errors.

- [ ] **Step 2: Uninstall CRA**

```bash
npm uninstall react-scripts @babel/plugin-proposal-private-property-in-object
```

Expected: both packages removed cleanly.

- [ ] **Step 3: Verify package.json dependencies look correct**

`dependencies` should contain no `react-scripts`. `devDependencies` should contain `vite`, `@vitejs/plugin-react`, `vitest`, `@vitest/coverage-v8`, `jsdom`. The `@babel/plugin-proposal-private-property-in-object` entry should be gone.

- [ ] **Step 4: Update scripts and remove CRA-specific keys in package.json**

Open `package.json`. Make these changes:

Replace the `"scripts"` block:
```json
"scripts": {
  "start": "vite",
  "build": "vite build",
  "preview": "vite preview",
  "test": "vitest run"
},
```

Remove the entire `"eslintConfig"` key (was CRA-only; will be replaced by `.eslintrc.json`).

Remove the entire `"jest"` key (the `moduleNameMapper` workaround is no longer needed).

- [ ] **Step 5: Commit**

```bash
git add package.json package-lock.json
git commit -m "chore: swap react-scripts for vite + vitest"
```

---

### Task 2: Create vite.config.js

**Files:**
- Create: `vite.config.js`

- [ ] **Step 1: Create the config file**

Create `/home/sps/sources/liferpg/vite.config.js`:

```js
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { fileURLToPath, URL } from 'node:url';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      src: fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/setupTests.js'],
    globals: true,
  },
});
```

The `resolve.alias` maps bare `src/...` imports (used throughout the app) to the absolute `src/` directory, matching the `jsconfig.json` `baseUrl`. The `test.globals: true` makes `vi`, `describe`, `it`, `expect`, etc. available without explicit imports.

- [ ] **Step 2: Commit**

```bash
git add vite.config.js
git commit -m "chore: add vite.config.js with react plugin, src alias, vitest config"
```

---

### Task 3: Create root index.html

**Files:**
- Create: `index.html` (project root)
- Delete: `public/index.html`

Vite uses `index.html` at the project root as the entry point. Static assets remain in `public/` and are served as-is.

- [ ] **Step 1: Create root index.html**

Create `/home/sps/sources/liferpg/index.html`:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="LifeRPG" />
    <link rel="apple-touch-icon" href="/logo192.png" />
    <link rel="manifest" href="/manifest.json" />
    <title>Liferpg</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
```

Key changes from `public/index.html`:
- `%PUBLIC_URL%/` → `/` (Vite serves `public/` at root automatically)
- Added `<script type="module" src="/src/main.jsx">` — Vite entry point

- [ ] **Step 2: Delete public/index.html**

```bash
rm public/index.html
```

- [ ] **Step 3: Commit**

```bash
git add index.html public/index.html
git commit -m "chore: move index.html to project root for vite, remove %PUBLIC_URL% placeholders"
```

---

### Task 4: Rename entry point, delete reportWebVitals

**Files:**
- Rename: `src/index.js` → `src/main.jsx`
- Delete: `src/reportWebVitals.js`

- [ ] **Step 1: Create src/main.jsx**

Create `/home/sps/sources/liferpg/src/main.jsx`:

```jsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

`reportWebVitals` is removed — the web-vitals v5 API changed (no `getFID`) and the call was a no-op.

- [ ] **Step 2: Delete old files**

```bash
rm src/index.js src/reportWebVitals.js
```

- [ ] **Step 3: Commit**

```bash
git add src/main.jsx src/index.js src/reportWebVitals.js
git commit -m "chore: rename entry to main.jsx, remove reportWebVitals"
```

---

### Task 5: Update setupTests.js

**Files:**
- Modify: `src/setupTests.js`

Vitest's jsdom environment provides `TextEncoder`/`TextDecoder` natively — the polyfill is no longer needed.

- [ ] **Step 1: Remove the polyfill**

Replace the entire content of `src/setupTests.js` with:

```js
import '@testing-library/jest-dom';
```

- [ ] **Step 2: Commit**

```bash
git add src/setupTests.js
git commit -m "chore: remove TextEncoder polyfill from setupTests (vitest jsdom provides it)"
```

---

### Task 6: Migrate test files from Jest globals to Vitest

**Files:**
- Modify: `src/components/Character/Character.test.jsx`
- Modify: `src/components/EditCharacterDialog/EditCharacterDialog.test.jsx`

With `globals: true`, Vitest exposes `vi` (not `jest`) as the global mock utility. Replace all `jest.mock` → `vi.mock` and `jest.fn()` → `vi.fn()`.

- [ ] **Step 1: Update Character.test.jsx**

Replace the entire content of `src/components/Character/Character.test.jsx`:

```jsx
import { render, screen } from '@testing-library/react';
import { Character } from './Character';

vi.mock('components/EditCharacterDialog/EditCharacterDialog', () => ({
  EditCharacterDialog: () => null,
}));

const base = { name: 'Hero', favour: 0 };

test('renders traits section when traits exist', () => {
  const character = {
    ...base,
    traits: [
      { name: 'Siła', value: '12' },
      { name: 'Zręczność', value: 'wysoka' },
    ],
  };
  render(<Character character={character} user={null} />);
  expect(screen.getByText('Cechy')).toBeInTheDocument();
  expect(screen.getByText('Siła')).toBeInTheDocument();
  expect(screen.getByText('12')).toBeInTheDocument();
  expect(screen.getByText('Zręczność')).toBeInTheDocument();
  expect(screen.getByText('wysoka')).toBeInTheDocument();
});

test('does not render traits section when traits array is empty', () => {
  render(<Character character={{ ...base, traits: [] }} user={null} />);
  expect(screen.queryByText('Cechy')).not.toBeInTheDocument();
});

test('does not render traits section when traits field is absent', () => {
  render(<Character character={base} user={null} />);
  expect(screen.queryByText('Cechy')).not.toBeInTheDocument();
});
```

- [ ] **Step 2: Update EditCharacterDialog.test.jsx**

Replace the entire content of `src/components/EditCharacterDialog/EditCharacterDialog.test.jsx`:

```jsx
import { render, screen, fireEvent } from '@testing-library/react';
import { EditCharacterDialog } from './EditCharacterDialog';

vi.mock('../../firebase', () => ({ db: {} }));
vi.mock('firebase/firestore', () => ({
  doc: vi.fn(),
  updateDoc: vi.fn(() => Promise.resolve()),
}));
vi.mock('@tanstack/react-query', () => ({
  useQueryClient: () => ({
    invalidateQueries: vi.fn(),
    getQueriesData: vi.fn(() => []),
  }),
}));

const character = {
  id: 'c1',
  name: 'Hero',
  level: 5,
  current_xp: 100,
  next_level_xp: 200,
  gold: 30,
  gold_usd: 0,
  favour: 0,
  traits: [
    { name: 'Siła', value: '12' },
    { name: 'Zręczność', value: '8' },
  ],
};

test('renders existing traits in the dialog', () => {
  render(
    <EditCharacterDialog
      charToEdit={character}
      open={true}
      handleClose={vi.fn()}
    />
  );
  expect(screen.getByText('Siła')).toBeInTheDocument();
  expect(screen.getByDisplayValue('12')).toBeInTheDocument();
  expect(screen.getByText('Zręczność')).toBeInTheDocument();
  expect(screen.getByDisplayValue('8')).toBeInTheDocument();
});

test('editing a trait value updates local state', () => {
  render(
    <EditCharacterDialog
      charToEdit={character}
      open={true}
      handleClose={vi.fn()}
    />
  );
  const input = screen.getByDisplayValue('12');
  fireEvent.change(input, { target: { value: '15' } });
  expect(screen.getByDisplayValue('15')).toBeInTheDocument();
});

test('deleting a trait removes it from the list', () => {
  render(
    <EditCharacterDialog
      charToEdit={character}
      open={true}
      handleClose={vi.fn()}
    />
  );
  const deleteButtons = screen.getAllByLabelText('usuń cechę');
  fireEvent.click(deleteButtons[0]);
  expect(screen.queryByText('Siła')).not.toBeInTheDocument();
  expect(screen.getByText('Zręczność')).toBeInTheDocument();
});

test('adding a new trait appends it to the list', () => {
  render(
    <EditCharacterDialog
      charToEdit={character}
      open={true}
      handleClose={vi.fn()}
    />
  );
  const nameInput = screen.getByPlaceholderText('Nowa cecha...');
  fireEvent.change(nameInput, { target: { value: 'Charyzma' } });

  const valueInput = screen.getByPlaceholderText('Wartość');
  fireEvent.change(valueInput, { target: { value: 'wysoka' } });

  fireEvent.click(screen.getByLabelText('dodaj cechę'));

  expect(screen.getByText('Charyzma')).toBeInTheDocument();
  expect(screen.getByDisplayValue('wysoka')).toBeInTheDocument();
  expect(nameInput.value).toBe('');
  expect(valueInput.value).toBe('');
});
```

- [ ] **Step 3: Run tests**

```bash
npm test
```

Expected output:
```
✓ src/App.test.js
✓ src/components/Character/Character.test.jsx
✓ src/components/EditCharacterDialog/EditCharacterDialog.test.jsx

Test Files  3 passed (3)
Tests       8 passed (8)
```

- [ ] **Step 4: Commit**

```bash
git add src/components/Character/Character.test.jsx src/components/EditCharacterDialog/EditCharacterDialog.test.jsx
git commit -m "chore: migrate test mocks from jest.mock/jest.fn to vi.mock/vi.fn"
```

---

### Task 7: Extract ESLint config

**Files:**
- Create: `.eslintrc.json`
- Modify: `package.json` (already done in Task 1 Step 4 — verify `eslintConfig` key is gone)

ESLint v8 is kept (eslint-config-standard@17 requires it). The config is extracted from the removed `eslintConfig` key in `package.json` to a standalone file, dropping `react-app`/`react-app/jest` extends which were CRA-only.

- [ ] **Step 1: Create .eslintrc.json**

Create `/home/sps/sources/liferpg/.eslintrc.json`:

```json
{
  "extends": ["standard", "google", "plugin:react/recommended"],
  "plugins": ["react", "import"],
  "parserOptions": {
    "ecmaVersion": "latest",
    "sourceType": "module",
    "ecmaFeatures": { "jsx": true }
  },
  "env": {
    "browser": true,
    "es2021": true,
    "node": true
  },
  "settings": {
    "react": { "version": "detect" }
  },
  "rules": {
    "react/react-in-jsx-scope": "off"
  }
}
```

`react/react-in-jsx-scope` is off because React 17+ JSX transform does not require `import React` in scope.

- [ ] **Step 2: Verify lint runs**

```bash
npx eslint src/App.js
```

Expected: no output (clean) or only warnings — no crash/config error.

- [ ] **Step 3: Commit**

```bash
git add .eslintrc.json
git commit -m "chore: extract eslint config to .eslintrc.json, drop react-app extends"
```

---

### Task 8: Verify build

- [ ] **Step 1: Run production build**

```bash
npm run build
```

Expected: Vite outputs a `dist/` directory with no errors. No CRA deprecation warnings.

- [ ] **Step 2: Run tests one final time**

```bash
npm test
```

Expected: `Tests  8 passed (8)`

- [ ] **Step 3: Verify npm install is clean**

```bash
npm install
```

Expected: no `ERESOLVE` errors, no CRA-related deprecation warnings (stable, w3c-hr-time, svgo, workbox-* should all be gone).

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: complete CRA to Vite + Vitest migration"
```
