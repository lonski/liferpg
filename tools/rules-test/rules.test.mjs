import { test, before, after } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc } from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'liferpg-rules-test',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
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
