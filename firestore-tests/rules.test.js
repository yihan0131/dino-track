// Tests the proposed Firestore rules on the local emulator (never the live DB).
// "app" tests = things Dino Track really does and must keep working.
// "attack" tests = holes in the old rules that must now be blocked.
import { test, before, beforeEach, after } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, addDoc, collection,
  increment, arrayUnion, runTransaction,
} from 'firebase/firestore';

let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-dino-rules',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8085 },
  });
});
after(async () => { await env.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/alice'), { id: 'alice', username: 'Alice', ecoPoints: 100, dinoStage: 'Baby Dino', processedReports: [] });
    await setDoc(doc(db, 'users/bob'), { id: 'bob', username: 'Bob', ecoPoints: 100, dinoStage: 'Baby Dino', isAdmin: false });
    await setDoc(doc(db, 'users/admin'), { id: 'admin', username: 'Admin', ecoPoints: 0, dinoStage: 'Egg', isAdmin: true });
    await setDoc(doc(db, 'eco_challenges/sys1'), { title: 'Recycle at Home', createdBy: 'system', participantsCount: 1 });
    await setDoc(doc(db, 'user_challenges/uc-alice'), {
      userId: 'alice', challengeId: 'sys1', currentStreak: 1,
      checkInPhotos: [{ photoUrl: 'p1', reported: false }],
    });
    await setDoc(doc(db, 'recycling_goals/g1'), { userId: 'alice', title: 'Goal' });
    await setDoc(doc(db, 'photo_reports/r1'), { userChallengeId: 'uc-alice', photoUrl: 'p1', status: 'pending', processed: false });
  });
});

// ---------- users ----------
test('app: sign-up creates own profile (no isAdmin field)', async () => {
  await assertSucceeds(setDoc(doc(as('carol'), 'users/carol'),
    { id: 'carol', username: 'Carol', email: 'c@x', ecoPoints: 0, dinoName: 'Eco Dino', dinoStage: 'Egg' }));
});
test('app: profile save writes the whole User (isAdmin: false unchanged)', async () => {
  await assertSucceeds(updateDoc(doc(as('alice'), 'users/alice'),
    { username: 'Alice2', ecoPoints: 100, dinoStage: 'Baby Dino', isAdmin: false, profileImageUrl: 'x' }));
});
test('app: earning points on own account (transaction)', async () => {
  const db = as('alice');
  await assertSucceeds(runTransaction(db, async (t) => {
    const ref = doc(db, 'users/alice');
    const snap = await t.get(ref);
    t.update(ref, { ecoPoints: snap.data().ecoPoints + 20, dinoStage: 'Baby Dino', hasUnseenLevelUp: true });
  }));
});
test('app: clear own level-up flag', async () => {
  await assertSucceeds(updateDoc(doc(as('alice'), 'users/alice'), { hasUnseenLevelUp: false }));
});
test('app: leaderboard reads another user (username)', async () => {
  await assertSucceeds(getDoc(doc(as('bob'), 'users/alice')));
});
test('app: admin rejects a photo -> deducts 2 points + processedReports', async () => {
  const db = as('admin');
  await assertSucceeds(runTransaction(db, async (t) => {
    const ref = doc(db, 'users/alice');
    const snap = await t.get(ref);
    t.update(ref, { ecoPoints: snap.data().ecoPoints - 2, dinoStage: 'Cracked Egg', hasUnseenLevelUp: true });
  }));
  await assertSucceeds(updateDoc(doc(db, 'users/alice'), { processedReports: arrayUnion('r1') }));
});
test('attack: make yourself admin', async () => {
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), { isAdmin: true }));
});
test('attack: sign up as admin', async () => {
  await assertFails(setDoc(doc(as('mallory'), 'users/mallory'), { id: 'mallory', ecoPoints: 0, isAdmin: true }));
});
test('attack: raise another user\'s points', async () => {
  await assertFails(updateDoc(doc(as('bob'), 'users/alice'), { ecoPoints: 99999 }));
});
test('attack: lower another user\'s points (non-admin)', async () => {
  await assertFails(updateDoc(doc(as('bob'), 'users/alice'), { ecoPoints: 0 }));
});
test('attack: admin raising someone\'s points', async () => {
  await assertFails(updateDoc(doc(as('admin'), 'users/alice'), { ecoPoints: 5000 }));
});
test('attack: admin renaming someone', async () => {
  await assertFails(updateDoc(doc(as('admin'), 'users/alice'), { username: 'hacked' }));
});
test('attack: overwrite another user\'s profile', async () => {
  await assertFails(setDoc(doc(as('bob'), 'users/alice'), { id: 'alice', ecoPoints: 0 }));
});

// ---------- user_challenges ----------
test('app: owner checks in (progress fields)', async () => {
  await assertSucceeds(updateDoc(doc(as('alice'), 'user_challenges/uc-alice'),
    { currentStreak: 2, checkInDates: [1], checkInPhotos: [{ photoUrl: 'p1' }, { photoUrl: 'p2' }] }));
});
test('app: another user reports a photo (checkInPhotos only)', async () => {
  await assertSucceeds(updateDoc(doc(as('bob'), 'user_challenges/uc-alice'),
    { checkInPhotos: [{ photoUrl: 'p1', reported: true }] }));
});
test('app: admin approves/rejects (status + photos + reviewedAt)', async () => {
  await assertSucceeds(updateDoc(doc(as('admin'), 'user_challenges/uc-alice'),
    { checkInPhotos: [{ photoUrl: 'p1', rejected: true }], status: 'rejected', reviewedAt: 1 }));
});
test('app: owner leaves challenge', async () => {
  await assertSucceeds(deleteDoc(doc(as('alice'), 'user_challenges/uc-alice')));
});
test('app: join challenge (own user_challenge + participantsCount)', async () => {
  const db = as('bob');
  await assertSucceeds(setDoc(doc(db, 'user_challenges/uc-bob'), { userId: 'bob', challengeId: 'sys1' }));
  await assertSucceeds(updateDoc(doc(db, 'eco_challenges/sys1'), { participantsCount: increment(1) }));
});
test('attack: change someone else\'s streak', async () => {
  await assertFails(updateDoc(doc(as('bob'), 'user_challenges/uc-alice'), { currentStreak: 0 }));
});
test('attack: steal someone\'s challenge entry', async () => {
  await assertFails(updateDoc(doc(as('bob'), 'user_challenges/uc-alice'), { userId: 'bob' }));
});

// ---------- photo_reports ----------
test('app: anyone signed in files a report', async () => {
  await assertSucceeds(addDoc(collection(as('bob'), 'photo_reports'),
    { userChallengeId: 'uc-alice', photoUrl: 'p1', status: 'pending', processed: false }));
});
test('app: admin settles a report', async () => {
  await assertSucceeds(updateDoc(doc(as('admin'), 'photo_reports/r1'), { status: 'approved', processed: true }));
});
test('attack: non-admin settles a report', async () => {
  await assertFails(updateDoc(doc(as('bob'), 'photo_reports/r1'), { status: 'approved' }));
});

// ---------- recycling_goals ----------
test('app: signed-in user reads goals', async () => {
  await assertSucceeds(getDoc(doc(as('alice'), 'recycling_goals/g1')));
});
test('attack: read goals while logged out', async () => {
  await assertFails(getDoc(doc(anon(), 'recycling_goals/g1')));
});
