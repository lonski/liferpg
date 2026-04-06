# LifeRPG

A React web app that gamifies real life — users are RPG characters with levels, XP, gold, and a "favour" (mood/disposition) score tracked over time.

## Tech Stack

- **React 18** (Create React App)
- **Firebase 9** — Firestore (database) + Google Auth
- **MUI v5** (Material UI) — all UI components
- **React Query v3** — data fetching and cache invalidation
- **React Router v6** — client-side routing

## Commands

```bash
npm start        # dev server at localhost:3000
npm run build    # production build
npm test         # run tests (jest/react-testing-library)
```

## Project Structure

```
src/
  firebase.js                          # Firebase init, Google sign-in, Firestore exports
  App.js                               # Root: QueryClientProvider + router
  hooks/
    useAuth.js                         # Auth state; redirects to /login if unauthenticated
    useCharacters.js                   # Fetches characters from Firestore for current user
  components/
    Home/Home.jsx                      # Main page — renders character list
    Character/Character.jsx            # Character card (level, XP bar, gold, favour)
    EditCharacterDialog/               # Admin-only dialog to edit character stats
    Login/Login.jsx                    # Google sign-in page
```

## Firestore Data Model

**`users/{uid}`**
```
uid, name, email, authProvider, admin (bool)
```

**`characters/{id}`**
```
name, clazz, email, level, current_xp, next_level_xp, gold, gold_usd, favour
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

## Conventions

- Components use named exports (not default exports).
- Absolute imports are configured in `jsconfig.json` — `src/` is the root, so `import { X } from "components/X/X"` works.
- ESLint uses `eslint-config-google` + `eslint-config-standard`. Run `npx eslint src/` to check.
- No TypeScript — plain JS with PropTypes for component prop validation.
