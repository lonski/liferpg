# CRA → Vite + Vitest Migration

**Date:** 2026-04-06
**Status:** Approved

## Goal

Replace Create React App (`react-scripts`) with Vite for building and Vitest for testing. Eliminates all deprecated CRA dependencies, lifts the eslint v8 ceiling, and removes the compatibility workarounds added during the dependency upgrade (jest moduleNameMapper, TextEncoder polyfill).

## Approach

Option A: Vite + Vitest. Clean swap — no CRA customisations exist in this project, so no ejection or intermediate steps needed.

## Dependencies

**Remove:**
- `react-scripts`
- `@babel/plugin-proposal-private-property-in-object` (babel-preset-react-app artefact)

**Add (production):**
- `vite`
- `@vitejs/plugin-react`

**Add (dev):**
- `vitest`
- `@vitest/coverage-v8`
- `jsdom`
- `eslint@^9` (now unblocked from v8 constraint)
- `eslint-plugin-react-hooks`

**Keep:**
- All `@testing-library/*` packages — compatible with Vitest unchanged
- `eslint-config-standard`, `eslint-config-google`, `eslint-plugin-react`, `eslint-plugin-import`, `eslint-plugin-n`, `eslint-plugin-promise`

## Configuration files

### `vite.config.js` (new)
- `@vitejs/plugin-react` plugin
- `resolve.alias`: `src` → `<root>/src` (replaces jsconfig `baseUrl` for runtime)
- `test.environment`: `jsdom`
- `test.setupFiles`: `['./src/setupTests.js']`
- `test.globals`: `true` (no explicit imports needed in test files)

### `index.html` (move from `public/` to project root)
- Replace `%PUBLIC_URL%/` with `/`
- Add `<script type="module" src="/src/main.jsx"></script>` before `</body>`
- Delete `public/index.html`

### `package.json` scripts
| Old | New |
|-----|-----|
| `react-scripts start` | `vite` |
| `react-scripts build` | `vite build` |
| `react-scripts test` | `vitest run` |
| — | `vite preview` (new) |

Remove `"eslintConfig"` key (moves to `eslint.config.js`).
Remove `"jest"` key (moduleNameMapper workaround no longer needed).

### `eslint.config.js` (new flat config, replaces inline eslintConfig)
Flat config using eslint v9 API. Includes `eslint-config-standard`, `eslint-config-google`, `eslint-plugin-react`, `eslint-plugin-react-hooks`, `eslint-plugin-import`.

### `jsconfig.json`
Keep unchanged — IDE still uses it for path resolution and type checking.

## Source code changes

| File | Change |
|------|--------|
| `src/index.js` | Rename to `src/main.jsx`; remove `reportWebVitals` import/call |
| `src/reportWebVitals.js` | Delete — web-vitals v5 changed API, file is unused boilerplate |
| `src/setupTests.js` | Remove `TextEncoder`/`TextDecoder` polyfill (Vitest jsdom provides these natively) |
| `src/components/EditCharacterDialog/EditCharacterDialog.test.jsx` | Replace `jest.mock` → `vi.mock` |
| `src/App.test.js` | Replace `jest.fn()` → `vi.fn()` if present (none currently, but global `vi` replaces `jest`) |
| `src/components/Character/Character.test.jsx` | Same — verify no `jest.*` globals |

## What is NOT changing

- All application source files (`App.js`, components, hooks, firebase.js)
- All `@testing-library` test assertions — identical API
- `public/` static assets (`favicon.ico`, `logo192.png`, `manifest.json`, `robots.txt`)
- `jsconfig.json`

## Success criteria

- `npm install` completes with no peer dependency errors
- `npm run build` produces a production bundle in `dist/`
- `npm test` runs all 8 tests green
- No deprecated package warnings from CRA ecosystem
