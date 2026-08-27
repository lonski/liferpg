# Firestore rules tests

Emulator-backed tests for `firestore.rules` (at the repository root), written
with `@firebase/rules-unit-testing` and Node's built-in test runner.

## Install

```bash
npm ci --legacy-peer-deps
```

`--legacy-peer-deps` is **required**: `@firebase/rules-unit-testing@3` declares
a peer dependency on `firebase@^10`, while this suite runs against
`firebase@12`. A plain `npm ci` / `npm install` fails with `ERESOLVE`.

## Run

From the repository root, with the Firestore emulator started for you:

```bash
npx --yes firebase-tools emulators:exec \
  --only firestore --project liferpg-rules-test \
  "npm --prefix tools/rules-test test"
```

Any project id works — the emulator never contacts a real project — but keep
it consistent with CI (`liferpg-rules-test`). The emulator needs a JDK on the
PATH. Both GitHub workflows run exactly this command.
