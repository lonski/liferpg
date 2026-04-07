# LifeRPG

A React web app that gamifies real life — users are RPG characters with levels, XP, gold, and a "favour" (mood/disposition) score tracked over time.

## Tech Stack

- **React 19** + **Vite 8** — build tooling (replaced Create React App)
- **Firebase 12** — Firestore (database) + Google Auth
- **MUI v7** (Material UI) — all UI components
- **TanStack Query v5** (`@tanstack/react-query`) — data fetching and cache invalidation
- **React Router v7** — client-side routing
- **Vitest** — test runner (replaced Jest)

## Commands

```bash
npm start          # dev server at localhost:5173
npm run build      # production build → dist/
npm run preview    # serve production build locally
npm test           # run tests (vitest/react-testing-library)
```

## Project Structure

```
src/
  firebase.js                          # Firebase init, Google sign-in, Firestore exports
  App.jsx                              # Root: QueryClientProvider + router
  main.jsx                             # Vite entry point
  hooks/
    useAuth.js                         # Auth state; redirects to /login if unauthenticated
    useCharacters.js                   # Fetches characters from Firestore for current user
  components/
    Home/Home.jsx                      # Main page — renders character list
    Character/Character.jsx            # Character card (level, XP bar, gold, favour)
    EditCharacterDialog/               # Admin-only dialog to edit character stats
    Login/Login.jsx                    # Google sign-in page
index.html                             # Vite entry HTML (project root, not public/)
vite.config.js                         # Vite + Vitest configuration
tsconfig.json                          # Path aliases — baseUrl: "./src"
.eslintrc.json                         # ESLint config (standard + google + react)
.github/workflows/
  firebase-hosting-merge.yml           # Deploy to Firebase on push to master
  firebase-hosting-pull-request.yml    # Deploy preview on pull request
```

## Firestore Data Model

**`users/{uid}`**
```
uid, name, email, authProvider, admin (bool)
```

**`characters/{id}`**
```
name, clazz, email, level, current_xp, next_level_xp, gold, gold_usd, favour
traits: [{ name: string, value: string }]  (optional)
```

- Characters are linked to users via `email`.
- Admin users see **all** characters; regular users see only their own.

## Key Behaviors

- **Auth**: `useAuth` hook handles auth state and redirects. Must be used inside a React Router context.
- **Admin**: `user.admin === true` unlocks the edit button on each character card and shows all characters.
- **Favour**: integer; rendered as mood emoji (< -1 = very unhappy, -1 = unhappy, 0 = neutral, > 0 = happy).
- **Currency**: `gold` = PLN (złoty), `gold_usd` = USD. Both displayed as chips if present.
- **XP badge**: clicking the XP progress bar toggles a chip showing XP remaining to next level.
- **Cache**: React Query key `["characters", user]` — invalidated on user change and after edits.

## UI Language

The UI is in **Polish**. Labels in components (Poziom, Złoto, XP, Przychylność, etc.) are intentional — do not translate them.

## CI/CD

Two Firebase Hosting workflows in `.github/workflows/`:

- **`firebase-hosting-merge.yml`** — triggers on push to `master`; builds and deploys to the live channel.
- **`firebase-hosting-pull-request.yml`** — triggers on pull requests; builds and deploys a preview channel.

Both workflows run: `npm install && npm run build && rm -rf public && mv dist public`

**When changing the build pipeline** (output directory, build command, Node version, etc.), update both workflow files to match. The `dist/` directory is Vite's output — do not change `build.outDir` in `vite.config.js` without also updating the workflows.

## Conventions

- Components use named exports (not default exports).
- Absolute imports configured via `tsconfig.json` `baseUrl: "./src"` — resolved by Vite's native `resolve.tsconfigPaths`. Example: `import { X } from "components/X/X"`.
- JSX files use `.jsx` extension (`.js` files are not processed for JSX by Vite's Oxc transformer).
- ESLint uses `eslint-config-google` + `eslint-config-standard` + `eslint-plugin-react`. Run `npx eslint src/` to check.
- No TypeScript — plain JS with PropTypes for component prop validation.
- Tests use Vitest globals (`vi`, `describe`, `test`, `expect`) — no imports needed. Use `vi.mock`/`vi.fn`, not `jest.mock`/`jest.fn`.
