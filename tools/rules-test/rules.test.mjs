import { test, before, after } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc,
  setDoc,
  getDoc,
  getDocs,
  collection,
  query,
  where,
} from 'firebase/firestore';
import assert from 'node:assert/strict';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'liferpg-rules-test',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
  // Seeded here rather than in a second top-level `before`: node:test does not
  // guarantee that a later hook runs after this one, and the seeding needs
  // `env`.
  await seedCharacters();
});

after(async () => {
  await env.cleanup();
});

test('a user may create their own doc with both flags false', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(
    setDoc(doc(db, 'users/alice'), {
      uid: 'alice',
      name: 'Alice',
      email: 'alice@example.com',
      authProvider: 'google',
      admin: false,
      readOnlyOthers: false,
    })
  );
});

test('a user may not create their own doc as admin', async () => {
  const db = env.authenticatedContext('mallory').firestore();
  await assertFails(
    setDoc(doc(db, 'users/mallory'), {
      uid: 'mallory',
      email: 'm@example.com',
      admin: true,
      readOnlyOthers: false,
    })
  );
});

test('a user may not create a doc belonging to somebody else', async () => {
  const db = env.authenticatedContext('mallory').firestore();
  await assertFails(
    setDoc(doc(db, 'users/victim'), {
      uid: 'victim',
      email: 'v@example.com',
      admin: false,
      readOnlyOthers: false,
    })
  );
});

test('a user may not raise their own privileges after creation', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/alice'), {
      uid: 'alice',
      email: 'alice@example.com',
      admin: false,
      readOnlyOthers: false,
    });
  });
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'users/alice'), { admin: true }, { merge: true }));
});

test('a user may still read their own doc', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/bob'), { uid: 'bob', admin: false });
  });
  const db = env.authenticatedContext('bob').firestore();
  await assertSucceeds(getDoc(doc(db, 'users/bob')));
});

// --- /characters -----------------------------------------------------------
//
// The read boundary lives in the rule, not in the client's query. These tests
// therefore exercise the LIST/QUERY path the app actually issues from
// lib/data/character_repository.dart (an unconstrained collection query for
// admin/readOnlyOthers, `where('email','==',<own email>)` for everyone else),
// because Firestore evaluates a query against the rule as a whole and can
// reject a query whose equivalent single-document `get` it would allow.

const ADMIN = { uid: 'adm', email: 'adm@example.com' };
const RO = { uid: 'ro', email: 'ro@example.com' };
const ALICE = { uid: 'alice2', email: 'alice2@example.com' };
const BOB = { uid: 'bob2', email: 'bob2@example.com' };
// The lockout case: the character document's email differs only in case from
// the address the owner signs in with.
const CASEY = { uid: 'casey', email: 'casey@example.com' };

function ctxFor(u) {
  return env.authenticatedContext(u.uid, { email: u.email }).firestore();
}

async function seedCharacters() {
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    await setDoc(doc(db, 'users/adm'), { uid: 'adm', email: ADMIN.email, admin: true, readOnlyOthers: false });
    await setDoc(doc(db, 'users/ro'), { uid: 'ro', email: RO.email, admin: false, readOnlyOthers: true });
    await setDoc(doc(db, 'users/alice2'), { uid: 'alice2', email: ALICE.email, admin: false, readOnlyOthers: false });
    await setDoc(doc(db, 'users/bob2'), { uid: 'bob2', email: BOB.email, admin: false, readOnlyOthers: false });
    await setDoc(doc(db, 'users/casey'), { uid: 'casey', email: CASEY.email, admin: false, readOnlyOthers: false });

    await setDoc(doc(db, 'characters/c-alice'), { name: 'Alicja', email: ALICE.email, level: 3 });
    await setDoc(doc(db, 'characters/c-bob'), { name: 'Bob', email: BOB.email, level: 5 });
    await setDoc(doc(db, 'characters/c-casey'), { name: 'Casey', email: 'Casey@Example.com', level: 1 });
  });
}

test('an admin may run the unconstrained roster query', async () => {
  const db = ctxFor(ADMIN);
  const snap = await assertSucceeds(getDocs(collection(db, 'characters')));
  assert.deepEqual(snap.docs.map((d) => d.id).sort(), ['c-alice', 'c-bob', 'c-casey']);
});

test('a readOnlyOthers user may run the unconstrained roster query', async () => {
  const db = ctxFor(RO);
  const snap = await assertSucceeds(getDocs(collection(db, 'characters')));
  assert.equal(snap.size, 3);
});

test('a regular user may query their own characters by email', async () => {
  const db = ctxFor(ALICE);
  const snap = await assertSucceeds(
    getDocs(query(collection(db, 'characters'), where('email', '==', ALICE.email)))
  );
  assert.deepEqual(snap.docs.map((d) => d.id), ['c-alice']);
});

test('a regular user may NOT run the unconstrained roster query', async () => {
  const db = ctxFor(ALICE);
  await assertFails(getDocs(collection(db, 'characters')));
});

test("a regular user may NOT query somebody else's characters", async () => {
  const db = ctxFor(ALICE);
  await assertFails(
    getDocs(query(collection(db, 'characters'), where('email', '==', BOB.email)))
  );
});

test("a regular user may NOT getDoc somebody else's character", async () => {
  const db = ctxFor(ALICE);
  await assertFails(getDoc(doc(db, 'characters/c-bob')));
});

test('a regular user may getDoc their own character', async () => {
  const db = ctxFor(ALICE);
  await assertSucceeds(getDoc(doc(db, 'characters/c-alice')));
});

test('a regular user may not write a character', async () => {
  const db = ctxFor(ALICE);
  await assertFails(setDoc(doc(db, 'characters/c-alice'), { level: 99 }, { merge: true }));
});

test('a readOnlyOthers user may not write a character', async () => {
  const db = ctxFor(RO);
  await assertFails(setDoc(doc(db, 'characters/c-alice'), { level: 99 }, { merge: true }));
});

test('an admin may write any character', async () => {
  const db = ctxFor(ADMIN);
  await assertSucceeds(setDoc(doc(db, 'characters/c-bob'), { level: 6 }, { merge: true }));
});

// THE LOCKOUT CASE. Firestore string comparison is case-sensitive, so a
// character stored as 'Casey@Example.com' does NOT match an auth token email
// of 'casey@example.com'. Measured behaviour, deliberately NOT worked around
// in the rule: such a character becomes invisible to its own owner.
test('LOCKOUT: a case-mismatched character is DENIED to its owner (get)', async () => {
  const db = ctxFor(CASEY);
  await assertFails(getDoc(doc(db, 'characters/c-casey')));
});

test('LOCKOUT: the owner\'s own-email query returns the case-mismatched character not at all', async () => {
  const db = ctxFor(CASEY);
  // The query itself is permitted (it is constrained to the caller's own
  // email), but it matches nothing: the document's email has different case.
  const snap = await assertSucceeds(
    getDocs(query(collection(db, 'characters'), where('email', '==', CASEY.email)))
  );
  assert.equal(snap.size, 0, 'the owner sees an EMPTY roster, not their character');
});
