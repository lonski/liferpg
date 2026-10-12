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
  updateDoc,
  collection,
  query,
  where,
  serverTimestamp,
  deleteField,
  writeBatch,
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
    // Deliberately has NO `email` field at all, to measure what `.lower()`
    // does against a missing/undefined value.
    await setDoc(doc(db, 'characters/c-noemail'), { name: 'NoEmail', level: 1 });
  });
}

test('an admin may run the unconstrained roster query', async () => {
  const db = ctxFor(ADMIN);
  const snap = await assertSucceeds(getDocs(collection(db, 'characters')));
  assert.deepEqual(
    snap.docs.map((d) => d.id).sort(),
    ['c-alice', 'c-bob', 'c-casey', 'c-noemail']
  );
});

test('a readOnlyOthers user may run the unconstrained roster query', async () => {
  const db = ctxFor(RO);
  const snap = await assertSucceeds(getDocs(collection(db, 'characters')));
  assert.equal(snap.size, 4);
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

// THE FORMER LOCKOUT CASE. The rule now compares `.lower()` of both sides,
// so a character stored as 'Casey@Example.com' DOES match an auth token
// email of 'casey@example.com' at the rule-evaluation level: a direct get
// is allowed.
test('FIXED: a case-mismatched character is now allowed to its owner (get)', async () => {
  const db = ctxFor(CASEY);
  await assertSucceeds(getDoc(doc(db, 'characters/c-casey')));
});

// MEASURED AND STILL BROKEN AT THE QUERY LEVEL. The rule change only affects
// rule evaluation; it cannot change how Firestore's server-side index
// compares values for a `where('email','==', ...)` filter, and that
// comparison is exact-string / case-sensitive. So the owner's own-email
// query (the one the app actually issues from
// lib/data/character_repository.dart) still returns zero results for a
// differently-cased character document, even though the rule would now
// permit reading it directly. The rule fix alone does NOT make this
// character appear in the owner's roster in the app; the document's stored
// `email` value itself must be corrected to match the owner's login email.
test("STILL BROKEN: the owner's own-email query still returns the case-mismatched character not at all", async () => {
  const db = ctxFor(CASEY);
  const snap = await assertSucceeds(
    getDocs(query(collection(db, 'characters'), where('email', '==', CASEY.email)))
  );
  assert.equal(snap.size, 0, 'the owner still sees an EMPTY roster from this query, not their character');
});

// --- missing `email` field --------------------------------------------------
//
// `.lower()` is called on `resource.data.email` in the rule. If that field
// is absent, `resource.data.email` is undefined, and calling `.lower()` on
// it is expected to be an evaluation error. In Firestore security rules, an
// error during evaluation of an `allow` condition denies the request — but
// this is measured here, not assumed, and separately for each of the three
// clauses in the `||` chain (admin / readOnlyOthers / own-email) so that
// short-circuit evaluation is also confirmed rather than assumed.

test('an admin may getDoc a character document with no email field at all', async () => {
  const db = ctxFor(ADMIN);
  await assertSucceeds(getDoc(doc(db, 'characters/c-noemail')));
});

test('a readOnlyOthers user may getDoc a character document with no email field at all', async () => {
  const db = ctxFor(RO);
  await assertSucceeds(getDoc(doc(db, 'characters/c-noemail')));
});

test('a regular user is DENIED getDoc on a character document with no email field at all', async () => {
  const db = ctxFor(ALICE);
  await assertFails(getDoc(doc(db, 'characters/c-noemail')));
});

// --- /change_requests --------------------------------------------------

async function seedRequest(id, requesterUid) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `change_requests/${id}`), {
      characterId: 'c-alice',
      characterName: 'Alicja',
      requesterUid,
      requesterEmail: `${requesterUid}@example.com`,
      status: 'pending',
      changes: { current_xp: 50 },
    });
  });
}

test('a user may create a request for their own character', async () => {
  const db = ctxFor(ALICE);
  await assertSucceeds(
    setDoc(doc(db, 'change_requests/req-alice'), {
      characterId: 'c-alice',
      characterName: 'Alicja',
      requesterUid: ALICE.uid,
      requesterEmail: ALICE.email,
      status: 'pending',
      changes: { current_xp: 50 },
      createdAt: serverTimestamp(),
    })
  );
});

test("a user may not create a request for somebody else's character", async () => {
  const db = ctxFor(BOB);
  await assertFails(
    setDoc(doc(db, 'change_requests/req-bob-for-alice'), {
      characterId: 'c-alice',
      characterName: 'Alicja',
      requesterUid: BOB.uid,
      requesterEmail: BOB.email,
      status: 'pending',
      changes: { current_xp: 50 },
      createdAt: serverTimestamp(),
    })
  );
});

test("a user may not create a request in somebody else's name", async () => {
  const db = ctxFor(ALICE);
  await assertFails(
    setDoc(doc(db, 'change_requests/req-spoofed'), {
      characterId: 'c-alice',
      characterName: 'Alicja',
      requesterUid: BOB.uid,
      requesterEmail: ALICE.email,
      status: 'pending',
      changes: { current_xp: 50 },
      createdAt: serverTimestamp(),
    })
  );
});

test('a user may not create a request that is already accepted', async () => {
  const db = ctxFor(ALICE);
  await assertFails(
    setDoc(doc(db, 'change_requests/req-preaccepted'), {
      characterId: 'c-alice',
      characterName: 'Alicja',
      requesterUid: ALICE.uid,
      requesterEmail: ALICE.email,
      status: 'accepted',
      changes: { current_xp: 50 },
      createdAt: serverTimestamp(),
    })
  );
});

test('a user may not create a request with no changes at all', async () => {
  const db = ctxFor(ALICE);
  await assertFails(
    setDoc(doc(db, 'change_requests/req-empty-changes'), {
      characterId: 'c-alice',
      characterName: 'Alicja',
      requesterUid: ALICE.uid,
      requesterEmail: ALICE.email,
      status: 'pending',
      changes: {},
      createdAt: serverTimestamp(),
    })
  );
});

test('a user may not create a request with only a reason and no changes', async () => {
  const db = ctxFor(ALICE);
  await assertFails(
    setDoc(doc(db, 'change_requests/req-reason-only'), {
      characterId: 'c-alice',
      characterName: 'Alicja',
      requesterUid: ALICE.uid,
      requesterEmail: ALICE.email,
      status: 'pending',
      reason: 'Posprzątałem garaż',
      changes: {},
      createdAt: serverTimestamp(),
    })
  );
});

test("a user may read their own requests but not somebody else's", async () => {
  await seedRequest('req-alice-seeded', ALICE.uid);
  await seedRequest('req-bob-seeded', BOB.uid);
  const db = ctxFor(ALICE);

  await assertSucceeds(getDoc(doc(db, 'change_requests/req-alice-seeded')));
  await assertFails(getDoc(doc(db, 'change_requests/req-bob-seeded')));
  await assertSucceeds(
    getDocs(
      query(
        collection(db, 'change_requests'),
        where('requesterUid', '==', ALICE.uid)
      )
    )
  );
  await assertFails(getDocs(collection(db, 'change_requests')));
});

test('an admin may read every request and decide it', async () => {
  await seedRequest('req-for-admin', ALICE.uid);
  const db = ctxFor(ADMIN);

  await assertSucceeds(getDocs(collection(db, 'change_requests')));
  await assertSucceeds(
    updateDoc(doc(db, 'change_requests/req-for-admin'), {
      status: 'accepted',
      decidedBy: ADMIN.uid,
      decidedAt: serverTimestamp(),
      appliedChanges: { current_xp: 50 },
    })
  );
});

test('a non-admin may not decide a request, even their own', async () => {
  await seedRequest('req-self-decide', ALICE.uid);
  const db = ctxFor(ALICE);
  await assertFails(
    updateDoc(doc(db, 'change_requests/req-self-decide'), {
      status: 'accepted',
      decidedBy: ALICE.uid,
    })
  );
});

test('a user may cancel their own pending request', async () => {
  await seedRequest('req-cancel-mine', ALICE.uid);
  const db = ctxFor(ALICE);
  await assertSucceeds(
    updateDoc(doc(db, 'change_requests/req-cancel-mine'), {
      status: 'cancelled',
    })
  );
});

test("a user may not cancel somebody else's request", async () => {
  await seedRequest('req-cancel-other', BOB.uid);
  const db = ctxFor(ALICE);
  await assertFails(
    updateDoc(doc(db, 'change_requests/req-cancel-other'), {
      status: 'cancelled',
    })
  );
});

test('cancelling may not smuggle in other field changes', async () => {
  await seedRequest('req-cancel-smuggle', ALICE.uid);
  const db = ctxFor(ALICE);
  await assertFails(
    updateDoc(doc(db, 'change_requests/req-cancel-smuggle'), {
      status: 'cancelled',
      decidedBy: ALICE.uid,
    })
  );
});

test('a user may not cancel a request that is no longer pending', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'change_requests/req-cancel-decided'), {
      characterId: 'c-alice',
      characterName: 'Alicja',
      requesterUid: ALICE.uid,
      requesterEmail: ALICE.email,
      status: 'rejected',
      changes: { current_xp: 50 },
    });
  });
  const db = ctxFor(ALICE);
  await assertFails(
    updateDoc(doc(db, 'change_requests/req-cancel-decided'), {
      status: 'cancelled',
    })
  );
});

// --- /quests and /quest_roster ---------------------------------------------
//
// Self-contained: these seed their own fixtures rather than relying on
// seedCharacters(), which was written for the /characters and
// /change_requests tests above, not this feature.

test('any signed-in user may read an open quest', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q1'), {
      title: 'Posprzątaj garaż',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 50 },
    });
  });
  const db = env.authenticatedContext('bob').firestore();
  await assertSucceeds(getDoc(doc(db, 'quests/q1')));
});

test('a user may post an open board quest in their own name', async () => {
  const db = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  await assertSucceeds(
    setDoc(doc(db, 'quests/q2'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 30 },
    })
  );
});

test('a user may not post a quest in somebody else\'s name', async () => {
  const db = env.authenticatedContext('mallory', { email: 'mallory@example.com' }).firestore();
  await assertFails(
    setDoc(doc(db, 'quests/q3'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 30 },
    })
  );
});

test('direct assignment requires the target character to be on the quest roster', async () => {
  const db = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  await assertFails(
    setDoc(doc(db, 'quests/q4'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      assignedToCharacterId: 'not-on-roster',
      assignedToCharacterName: 'Grommash',
      assignedToEmail: 'grommash@example.com',
      status: 'assigned',
      reward: { current_xp: 30 },
    })
  );
});

test('direct assignment succeeds once the target is on the quest roster', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quest_roster/c1'), {
      characterName: 'Grommash',
      email: 'grommash@example.com',
    });
  });
  const db = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  await assertSucceeds(
    setDoc(doc(db, 'quests/q5'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      assignedToCharacterId: 'c1',
      assignedToCharacterName: 'Grommash',
      assignedToEmail: 'grommash@example.com',
      status: 'assigned',
      reward: { current_xp: 30 },
    })
  );
});

test('a quest reward may not carry a gold delta', async () => {
  const db = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  await assertFails(
    setDoc(doc(db, 'quests/q6'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 30, gold: 5 },
    })
  );
});

test('taking an open quest requires the taker to own the target character', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q7'), {
      title: 'Posprzątaj garaż',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 50 },
    });
    await setDoc(doc(ctx.firestore(), 'characters/c-bob'), {
      name: 'Bob the Bold',
      email: 'bob@example.com',
    });
  });
  const db = env.authenticatedContext('mallory', { email: 'mallory@example.com' }).firestore();
  await assertFails(
    updateDoc(doc(db, 'quests/q7'), {
      status: 'assigned',
      assignedToCharacterId: 'c-bob',
      assignedToCharacterName: 'Bob the Bold',
      assignedToEmail: 'mallory@example.com',
    })
  );
});

test('taking an open quest for your own character succeeds', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q8'), {
      title: 'Posprzątaj garaż',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 50 },
    });
    await setDoc(doc(ctx.firestore(), 'characters/c-bob2'), {
      name: 'Bob the Bold',
      email: 'bob@example.com',
    });
  });
  const db = env.authenticatedContext('bob', { email: 'bob@example.com' }).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'quests/q8'), {
      status: 'assigned',
      assignedToCharacterId: 'c-bob2',
      assignedToCharacterName: 'Bob the Bold',
      assignedToEmail: 'bob@example.com',
    })
  );
});

test('only the poster may withdraw an open quest', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q9'), {
      title: 'Posprzątaj garaż',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 50 },
    });
  });
  const mallory = env.authenticatedContext('mallory', { email: 'mallory@example.com' }).firestore();
  await assertFails(updateDoc(doc(mallory, 'quests/q9'), { status: 'cancelled' }));

  const alice = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  await assertSucceeds(updateDoc(doc(alice, 'quests/q9'), { status: 'cancelled' }));
});

test('the poster may edit title/description/reward of their own open quest', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q14'), {
      title: 'Posprzątaj garaż',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 50 },
    });
  });
  const db = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'quests/q14'), {
      title: 'Posprzątaj garaż (gruntownie)',
      description: 'Też pod samochodem',
      reward: { current_xp: 80 },
    })
  );
});

test('editing a quest may not be done by anyone but the poster', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q15'), {
      title: 'Posprzątaj garaż',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 50 },
    });
  });
  const mallory = env.authenticatedContext('mallory', { email: 'mallory@example.com' }).firestore();
  await assertFails(updateDoc(doc(mallory, 'quests/q15'), { title: 'Zmieniony tytuł' }));
});

test('editing may not touch fields outside title/description/reward', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q16'), {
      title: 'Posprzątaj garaż',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 50 },
    });
  });
  const db = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  await assertFails(
    updateDoc(doc(db, 'quests/q16'), { title: 'Zmieniony tytuł', status: 'cancelled' })
  );
});

test('editing may not leave a quest reward carrying a gold delta', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q17'), {
      title: 'Posprzątaj garaż',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 50 },
    });
  });
  const db = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  await assertFails(
    updateDoc(doc(db, 'quests/q17'), { reward: { current_xp: 50, gold: 5 } })
  );
});

test('a quest can no longer be edited once it has been taken', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q18'), {
      title: 'Posprzątaj garaż',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      assignedToCharacterId: 'c-bob7',
      assignedToCharacterName: 'Bob the Bold',
      assignedToEmail: 'bob@example.com',
      status: 'assigned',
      reward: { current_xp: 50 },
    });
  });
  const db = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  await assertFails(updateDoc(doc(db, 'quests/q18'), { title: 'Zmieniony tytuł' }));
});

test('only the current holder may abandon or mark an assigned quest complete', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q10'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      assignedToCharacterId: 'c-bob3',
      assignedToCharacterName: 'Bob the Bold',
      assignedToEmail: 'bob@example.com',
      status: 'assigned',
      reward: { current_xp: 30 },
    });
  });
  const mallory = env.authenticatedContext('mallory', { email: 'mallory@example.com' }).firestore();
  await assertFails(updateDoc(doc(mallory, 'quests/q10'), { status: 'pending_review' }));

  const bob = env.authenticatedContext('bob', { email: 'bob@example.com' }).firestore();
  await assertSucceeds(updateDoc(doc(bob, 'quests/q10'), { status: 'pending_review' }));
});

test('the current holder may abandon an assigned quest, clearing the assignment fields', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q11'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      assignedToCharacterId: 'c-bob4',
      assignedToCharacterName: 'Bob the Bold',
      assignedToEmail: 'bob@example.com',
      status: 'assigned',
      reward: { current_xp: 30 },
    });
  });
  const bob = env.authenticatedContext('bob', { email: 'bob@example.com' }).firestore();
  await assertSucceeds(
    updateDoc(doc(bob, 'quests/q11'), {
      status: 'open',
      assignedToCharacterId: deleteField(),
      assignedToCharacterName: deleteField(),
      assignedToEmail: deleteField(),
    })
  );
});

test('only the current holder may abandon an assigned quest', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q12'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      assignedToCharacterId: 'c-bob5',
      assignedToCharacterName: 'Bob the Bold',
      assignedToEmail: 'bob@example.com',
      status: 'assigned',
      reward: { current_xp: 30 },
    });
  });
  const mallory = env.authenticatedContext('mallory', { email: 'mallory@example.com' }).firestore();
  await assertFails(
    updateDoc(doc(mallory, 'quests/q12'), {
      status: 'open',
      assignedToCharacterId: deleteField(),
      assignedToCharacterName: deleteField(),
      assignedToEmail: deleteField(),
    })
  );
});

test('abandoning may not leave stale assignment values on an open quest', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q13'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      assignedToCharacterId: 'c-bob6',
      assignedToCharacterName: 'Bob the Bold',
      assignedToEmail: 'bob@example.com',
      status: 'assigned',
      reward: { current_xp: 30 },
    });
  });
  const bob = env.authenticatedContext('bob', { email: 'bob@example.com' }).firestore();
  await assertFails(
    updateDoc(doc(bob, 'quests/q13'), {
      status: 'open',
      // Deliberately NOT deleted: the fields still carry values, which the
      // tightened abandon rule must reject even though `status` itself is a
      // legal transition and the touched-keys set is still within hasOnly().
    })
  );
});

// --- Daily quests -----------------------------------------------------------

test('a non-admin may not post a daily quest', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quest_roster/c-daily1'), {
      characterName: 'Grommash',
      email: 'grommash@example.com',
    });
  });
  const mallory = env.authenticatedContext('mallory', { email: 'mallory@example.com' }).firestore();
  await assertFails(
    setDoc(doc(mallory, 'quests/q19'), {
      title: 'Wyprowadzić psa',
      posterUid: 'mallory',
      posterEmail: 'mallory@example.com',
      posterName: 'Mallory',
      assignedToCharacterId: 'c-daily1',
      assignedToCharacterName: 'Grommash',
      assignedToEmail: 'grommash@example.com',
      status: 'assigned',
      isDaily: true,
      reward: { current_xp: 10 },
    })
  );
});

test('an admin may post a daily quest directly assigned to a roster character', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/admin2'), { admin: true });
    await setDoc(doc(ctx.firestore(), 'quest_roster/c-daily2'), {
      characterName: 'Grommash',
      email: 'grommash@example.com',
    });
  });
  const admin = env.authenticatedContext('admin2', { email: 'admin2@example.com' }).firestore();
  await assertSucceeds(
    setDoc(doc(admin, 'quests/q20'), {
      title: 'Wyprowadzić psa',
      posterUid: 'admin2',
      posterEmail: 'admin2@example.com',
      posterName: 'Admin',
      assignedToCharacterId: 'c-daily2',
      assignedToCharacterName: 'Grommash',
      assignedToEmail: 'grommash@example.com',
      status: 'assigned',
      isDaily: true,
      reward: { current_xp: 10 },
    })
  );
});

test('an admin may post a dailyShared quest open on the board with no target', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/admin3'), { admin: true });
  });
  const admin = env.authenticatedContext('admin3', { email: 'admin3@example.com' }).firestore();
  await assertSucceeds(
    setDoc(doc(admin, 'quests/q21'), {
      title: 'Umyć okna',
      posterUid: 'admin3',
      posterEmail: 'admin3@example.com',
      posterName: 'Admin',
      status: 'open',
      isDaily: true,
      dailyShared: true,
      reward: { current_xp: 10 },
    })
  );
});

test('a non-admin may not post an open daily quest either', async () => {
  const db = env.authenticatedContext('mallory', { email: 'mallory@example.com' }).firestore();
  await assertFails(
    setDoc(doc(db, 'quests/q21b'), {
      title: 'Umyć okna',
      posterUid: 'mallory',
      posterEmail: 'mallory@example.com',
      posterName: 'Mallory',
      status: 'open',
      isDaily: true,
      dailyShared: true,
      reward: { current_xp: 10 },
    })
  );
});

test('an open daily quest still may not carry an assignment', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/admin3b'), { admin: true });
  });
  const admin = env.authenticatedContext('admin3b', { email: 'admin3b@example.com' }).firestore();
  await assertFails(
    setDoc(doc(admin, 'quests/q21c'), {
      title: 'Umyć okna',
      posterUid: 'admin3b',
      posterEmail: 'admin3b@example.com',
      posterName: 'Admin',
      status: 'open',
      assignedToCharacterId: 'c-daily1',
      isDaily: true,
      dailyShared: true,
      reward: { current_xp: 10 },
    })
  );
});

test('taking a dailyShared quest off the board works exactly like an ordinary open quest', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q23'), {
      title: 'Umyć okna',
      posterUid: 'admin5',
      posterEmail: 'admin5@example.com',
      posterName: 'Admin',
      status: 'open',
      isDaily: true,
      dailyShared: true,
      reward: { current_xp: 10 },
    });
    await setDoc(doc(ctx.firestore(), 'characters/c-daily4'), {
      name: 'Bob the Bold',
      email: 'bob@example.com',
    });
  });
  const bob = env.authenticatedContext('bob', { email: 'bob@example.com' }).firestore();
  await assertSucceeds(
    updateDoc(doc(bob, 'quests/q23'), {
      status: 'assigned',
      assignedToCharacterId: 'c-daily4',
      assignedToCharacterName: 'Bob the Bold',
      assignedToEmail: 'bob@example.com',
    })
  );
});

test('marking a daily quest complete may also stamp lastCompletedDate', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q22'), {
      title: 'Wyprowadzić psa',
      posterUid: 'admin4',
      posterEmail: 'admin4@example.com',
      posterName: 'Admin',
      assignedToCharacterId: 'c-daily3',
      assignedToCharacterName: 'Grommash',
      assignedToEmail: 'bob@example.com',
      status: 'assigned',
      isDaily: true,
      reward: { current_xp: 10 },
    });
  });
  const bob = env.authenticatedContext('bob', { email: 'bob@example.com' }).firestore();
  await assertSucceeds(
    updateDoc(doc(bob, 'quests/q22'), {
      status: 'pending_review',
      lastCompletedDate: '2026-09-18',
    })
  );
});

test('only an admin may write to quest_roster', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/admin1'), { admin: true });
  });
  const mallory = env.authenticatedContext('mallory').firestore();
  await assertFails(
    setDoc(doc(mallory, 'quest_roster/c1'), { characterName: 'Grommash', email: 'g@example.com' })
  );

  const admin = env.authenticatedContext('admin1').firestore();
  await assertSucceeds(
    setDoc(doc(admin, 'quest_roster/c1'), { characterName: 'Grommash', email: 'g@example.com' })
  );
});

// --- electronics days ------------------------------------------------------

function claimRequest(user, characterId, changes) {
  return {
    characterId,
    characterName: 'Alicja',
    requesterUid: user.uid,
    requesterEmail: user.email,
    status: 'pending',
    changes,
    createdAt: serverTimestamp(),
  };
}

test('a user may request an electronics day for their own character', async () => {
  await assertSucceeds(setDoc(doc(ctxFor(ALICE), 'change_requests/el-ok'),
    claimRequest(ALICE, 'c-alice', { electronics_claim: '2026-10-22' })));
});

test("a user may not request an electronics day for somebody else's character", async () => {
  await assertFails(setDoc(doc(ctxFor(BOB), 'change_requests/el-bob'),
    claimRequest(BOB, 'c-alice', { electronics_claim: '2026-10-22' })));
});

test('an electronics claim may not be combined with other changes', async () => {
  await assertFails(setDoc(doc(ctxFor(ALICE), 'change_requests/el-mixed'),
    claimRequest(ALICE, 'c-alice', { electronics_claim: '2026-10-22', current_xp: 50 })));
});

test('an electronics claim must be a YYYY-MM-DD string', async () => {
  await assertFails(setDoc(doc(ctxFor(ALICE), 'change_requests/el-bad1'),
    claimRequest(ALICE, 'c-alice', { electronics_claim: 'jutro' })));
  await assertFails(setDoc(doc(ctxFor(ALICE), 'change_requests/el-bad2'),
    claimRequest(ALICE, 'c-alice', { electronics_claim: 20261022 })));
});

test('a quest reward may not carry an electronics claim', async () => {
  const db = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  await assertFails(
    setDoc(doc(db, 'quests/q-el'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 30, electronics_claim: '2026-10-22' },
    })
  );
});

// --- /bosses -----------------------------------------------------------------
//
// Every boss write happens on a player's own client (there are no Cloud
// Functions), so these rules are what keeps attacks, joins and reward claims
// honest -- see BossRepository.

async function seedBoss(id, data) {
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    await setDoc(doc(db, 'characters/cb-alice'), {
      name: 'Alicja', email: ALICE.email, current_xp: 100, gold: 5,
      traits: [{ name: 'Odwaga', value: '1' }],
    });
    await setDoc(doc(db, 'characters/cb-bob'), { name: 'Bob', email: BOB.email, current_xp: 40 });
    await setDoc(doc(db, `bosses/${id}`), {
      name: 'Smok Ognisty', look: 'smok', maxHp: 100, hp: 100,
      reward: { current_xp: 50, gold: 20, traits: [{ name: 'Odwaga', value: '1' }] },
      targetCharacterId: null, targetCharacterName: null,
      status: 'active', createdBy: 'adm', createdByName: 'Admin',
      baseline: { 'cb-alice': 60, 'cb-bob': 40 },
      spent: {}, damage: {}, rewarded: {},
      ...data,
    });
  });
}

function blow(characterId, boss, paid, dealt, extra = {}) {
  const hp = Math.max(0, boss.hp - dealt);
  return {
    hp,
    spent: { ...boss.spent, [characterId]: (boss.spent[characterId] ?? 0) + paid },
    damage: { ...boss.damage, [characterId]: (boss.damage[characterId] ?? 0) + dealt },
    lastAttackerId: characterId,
    lastAttackerName: 'Alicja',
    ...(hp === 0 ? { status: 'defeated', defeatedAt: serverTimestamp() } : {}),
    ...extra,
  };
}

const FRESH = { hp: 100, spent: {}, damage: {} };

test('any signed-in user may read a boss; a signed-out one may not', async () => {
  await seedBoss('b-read', {});
  await assertSucceeds(getDoc(doc(ctxFor(BOB), 'bosses/b-read')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'bosses/b-read')));
});

test('only an admin may summon a boss', async () => {
  const boss = { name: 'Troll', look: 'troll', maxHp: 50, hp: 50, status: 'active',
    baseline: {}, spent: {}, damage: {}, rewarded: {} };
  await assertFails(setDoc(doc(ctxFor(ALICE), 'bosses/b-new'), boss));
  await assertSucceeds(setDoc(doc(ctxFor(ADMIN), 'bosses/b-new'), boss));
});

test('an owner may hit a boss with a tier blow paid from new XP', async () => {
  await seedBoss('b-hit', {});
  await assertSucceeds(updateDoc(doc(ctxFor(ALICE), 'bosses/b-hit'), blow('cb-alice', FRESH, 10, 10)));
});

test('a blow must be one of the four cost/damage pairs', async () => {
  await seedBoss('b-pair', {});
  await assertFails(updateDoc(doc(ctxFor(ALICE), 'bosses/b-pair'), blow('cb-alice', FRESH, 1, 10)));
  await assertFails(updateDoc(doc(ctxFor(ALICE), 'bosses/b-pair'), blow('cb-alice', FRESH, 10, 60)));
});

test('a blow may not cost more energy than XP gained since the boss appeared', async () => {
  // current_xp 100, baseline 60, already spent 35 -> 5 left.
  await seedBoss('b-poor', { spent: { 'cb-alice': 35 } });
  await assertFails(updateDoc(doc(ctxFor(ALICE), 'bosses/b-poor'),
    blow('cb-alice', { hp: 100, spent: { 'cb-alice': 35 }, damage: {} }, 10, 10)));
  await assertSucceeds(updateDoc(doc(ctxFor(ALICE), 'bosses/b-poor'),
    blow('cb-alice', { hp: 100, spent: { 'cb-alice': 35 }, damage: {} }, 1, 1)));
});

test("a player may not attack with somebody else's character", async () => {
  await seedBoss('b-other', {});
  await assertFails(updateDoc(doc(ctxFor(ALICE), 'bosses/b-other'), blow('cb-bob', FRESH, 1, 1)));
});

test('a boss meant for one character may not be hit by another', async () => {
  await seedBoss('b-bobs', { targetCharacterId: 'cb-bob', targetCharacterName: 'Bob' });
  await assertFails(updateDoc(doc(ctxFor(ALICE), 'bosses/b-bobs'), blow('cb-alice', FRESH, 1, 1)));
});

test('a blow must take exactly its damage off the HP', async () => {
  await seedBoss('b-hp', {});
  await assertFails(updateDoc(doc(ctxFor(ALICE), 'bosses/b-hp'),
    blow('cb-alice', FRESH, 1, 1, { hp: 50 })));
});

test('the killing blow defeats the boss, and must say so', async () => {
  await seedBoss('b-kill', { hp: 5 });
  const boss = { hp: 5, spent: {}, damage: {} };
  await assertFails(updateDoc(doc(ctxFor(ALICE), 'bosses/b-kill'),
    { ...blow('cb-alice', boss, 10, 10), status: 'active', defeatedAt: deleteField() }));
  await assertSucceeds(updateDoc(doc(ctxFor(ALICE), 'bosses/b-kill'), blow('cb-alice', boss, 10, 10)));
});

test('a beaten boss may not be hit again', async () => {
  await seedBoss('b-dead', { hp: 0, status: 'defeated' });
  await assertFails(updateDoc(doc(ctxFor(ALICE), 'bosses/b-dead'),
    blow('cb-alice', { hp: 0, spent: {}, damage: {} }, 1, 1)));
});

test('a late character joins with its current XP as baseline, nothing else', async () => {
  await seedBoss('b-join', { baseline: {} });
  await assertFails(updateDoc(doc(ctxFor(ALICE), 'bosses/b-join'),
    { baseline: { 'cb-alice': 0 }, lastJoinedId: 'cb-alice' }));
  await assertFails(updateDoc(doc(ctxFor(BOB), 'bosses/b-join'),
    { baseline: { 'cb-alice': 100 }, lastJoinedId: 'cb-alice' }));
  await assertSucceeds(updateDoc(doc(ctxFor(ALICE), 'bosses/b-join'),
    { baseline: { 'cb-alice': 100 }, lastJoinedId: 'cb-alice' }));
});

function claimBatch(db, bossId, characterId, character) {
  const batch = writeBatch(db);
  batch.update(doc(db, `characters/${characterId}`), { ...character, lastBossRewardId: bossId });
  batch.update(doc(db, `bosses/${bossId}`), { rewarded: { [characterId]: true }, lastClaimId: characterId });
  return batch.commit();
}

const ALICE_PAID = {
  current_xp: 150, xp_earned: 150, gold: 25,
  traits: [{ name: 'Odwaga', value: '2' }],
};

test('a fighter collects the exact reward together with the boss entry', async () => {
  await seedBoss('b-claim', { hp: 0, status: 'defeated', damage: { 'cb-alice': 60 } });
  await assertSucceeds(claimBatch(ctxFor(ALICE), 'b-claim', 'cb-alice', ALICE_PAID));
});

test('a reward may not be collected twice', async () => {
  await seedBoss('b-twice', { hp: 0, status: 'defeated', damage: { 'cb-alice': 60 },
    rewarded: { 'cb-alice': true } });
  await assertFails(claimBatch(ctxFor(ALICE), 'b-twice', 'cb-alice', ALICE_PAID));
});

test('a reward claim must pay exactly the reward', async () => {
  await seedBoss('b-greedy', { hp: 0, status: 'defeated', damage: { 'cb-alice': 60 } });
  await assertFails(claimBatch(ctxFor(ALICE), 'b-greedy', 'cb-alice',
    { ...ALICE_PAID, current_xp: 1000 }));
  await assertFails(claimBatch(ctxFor(ALICE), 'b-greedy', 'cb-alice',
    { ...ALICE_PAID, level: 99 }));
  await assertFails(claimBatch(ctxFor(ALICE), 'b-greedy', 'cb-alice',
    { ...ALICE_PAID, xp_earned: 5000 }));
});

test('only a character that dealt damage collects, and only from a beaten boss', async () => {
  await seedBoss('b-idle', { hp: 0, status: 'defeated', damage: { 'cb-bob': 100 } });
  await assertFails(claimBatch(ctxFor(ALICE), 'b-idle', 'cb-alice', ALICE_PAID));
  await seedBoss('b-alive', { hp: 40, damage: { 'cb-alice': 60 } });
  await assertFails(claimBatch(ctxFor(ALICE), 'b-alive', 'cb-alice', ALICE_PAID));
});

test('the character half of a claim is refused on its own', async () => {
  await seedBoss('b-half', { hp: 0, status: 'defeated', damage: { 'cb-alice': 60 } });
  await assertFails(updateDoc(doc(ctxFor(ALICE), 'characters/cb-alice'),
    { ...ALICE_PAID, lastBossRewardId: 'b-half' }));
});

test("a player may not collect for somebody else's character", async () => {
  await seedBoss('b-steal', { hp: 0, status: 'defeated', damage: { 'cb-alice': 60 } });
  await assertFails(claimBatch(ctxFor(BOB), 'b-steal', 'cb-alice', ALICE_PAID));
});

test('energy counts earned XP, so a level-up that zeroes current_xp keeps it', async () => {
  // Earned 100 (baseline 60 -> 40 energy), then levelled up to current_xp 0.
  await seedBoss('b-levelup', {});
  await env.withSecurityRulesDisabled(async (c) => {
    await updateDoc(doc(c.firestore(), 'characters/cb-alice'), { current_xp: 0, xp_earned: 100 });
  });
  await assertSucceeds(updateDoc(doc(ctxFor(ALICE), 'bosses/b-levelup'), blow('cb-alice', FRESH, 10, 10)));
  await assertFails(updateDoc(doc(ctxFor(ALICE), 'bosses/b-levelup'),
    blow('cb-alice', { hp: 90, spent: { 'cb-alice': 10 }, damage: { 'cb-alice': 10 } }, 50, 60)));
});

test('a late character joins with its earned XP, not its current XP', async () => {
  await seedBoss('b-join-earned', { baseline: {} });
  await env.withSecurityRulesDisabled(async (c) => {
    await updateDoc(doc(c.firestore(), 'characters/cb-alice'), { current_xp: 0, xp_earned: 300 });
  });
  await assertFails(updateDoc(doc(ctxFor(ALICE), 'bosses/b-join-earned'),
    { baseline: { 'cb-alice': 0 }, lastJoinedId: 'cb-alice' }));
  await assertSucceeds(updateDoc(doc(ctxFor(ALICE), 'bosses/b-join-earned'),
    { baseline: { 'cb-alice': 300 }, lastJoinedId: 'cb-alice' }));
});

test('a claim adds the reward XP to an already recorded xp_earned', async () => {
  await seedBoss('b-claim-earned', { hp: 0, status: 'defeated', damage: { 'cb-alice': 60 } });
  await env.withSecurityRulesDisabled(async (c) => {
    await updateDoc(doc(c.firestore(), 'characters/cb-alice'), { xp_earned: 400 });
  });
  await assertFails(claimBatch(ctxFor(ALICE), 'b-claim-earned', 'cb-alice', ALICE_PAID));
  await assertSucceeds(claimBatch(ctxFor(ALICE), 'b-claim-earned', 'cb-alice',
    { ...ALICE_PAID, xp_earned: 450 }));
});

test('an older app that leaves xp_earned out may still collect', async () => {
  await seedBoss('b-claim-old', { hp: 0, status: 'defeated', damage: { 'cb-alice': 60 } });
  const { xp_earned: _, ...oldPaid } = ALICE_PAID;
  await assertSucceeds(claimBatch(ctxFor(ALICE), 'b-claim-old', 'cb-alice', oldPaid));
});
