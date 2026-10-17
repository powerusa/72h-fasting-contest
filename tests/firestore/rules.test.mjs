import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, getDoc, getDocs, collection, serverTimestamp, Timestamp } from 'firebase/firestore';

let env;
const projectId = 'demo-fasting-contest';
const now = () => Timestamp.now();
const ago = hours => Timestamp.fromMillis(Date.now() - hours * 3600000);
const db = uid => env.authenticatedContext(uid).firestore();
const session = (id, uid, extra = {}) => ({
  id, userId: uid, displayName: 'Test participant', avatarColor: '#0A84FF', countryFlag: '🏁',
  startTime: serverTimestamp(), status: 'active', elapsedSeconds: 0,
  createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...extra
});
const contest = (id, uid, extra = {}) => ({
  id, title: 'Test contest', contestCode: 'FAST-ABC123', creatorUserId: uid,
  isPrivate: true, participantIds: [uid], createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...extra
});
async function seed(path, data) {
  await env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), path), data));
}
before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Run through the local Firestore emulator; production tests are forbidden.');
  env = await initializeTestEnvironment({ projectId, firestore: { rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8') } });
});
beforeEach(async () => env.clearFirestore());
after(async () => env?.cleanup());

test('authenticated users can create a session using server timestamps and read leaderboard', async () => {
  await assertSucceeds(setDoc(doc(db('alice'), 'fastingSessions', 's'), session('s', 'alice')));
  await assertSucceeds(getDocs(collection(db('bob'), 'fastingSessions')));
});
test('unauthenticated users cannot read or write sessions', async () => {
  const guest = env.unauthenticatedContext().firestore();
  await assertFails(getDocs(collection(guest, 'fastingSessions')));
  await assertFails(setDoc(doc(guest, 'fastingSessions', 's'), session('s', 'alice')));
});
test('session ownership cannot be forged', async () => {
  await assertFails(setDoc(doc(db('bob'), 'fastingSessions', 's'), session('s', 'alice')));
});
test('backdated and future start timestamps are rejected', async () => {
  for (const startTime of [ago(73), Timestamp.fromMillis(Date.now() + 3600000)]) {
    await assertFails(setDoc(doc(db('alice'), 'fastingSessions', 's'), session('s', 'alice', { startTime })));
  }
});
test('pre-completed sessions and prepopulated endTime are rejected', async () => {
  await assertFails(setDoc(doc(db('alice'), 'fastingSessions', 's'), session('s', 'alice', { status: 'completed', elapsedSeconds: 259200 })));
  await assertFails(setDoc(doc(db('alice'), 'fastingSessions', 's'), session('s', 'alice', { endTime: now() })));
});
test('a fast cannot complete before 72 server hours', async () => {
  await seed('fastingSessions/s', session('s', 'alice', { startTime: ago(1), createdAt: ago(1) }));
  await assertFails(updateDoc(doc(db('alice'), 'fastingSessions', 's'), { status: 'completed', elapsedSeconds: 259200, endTime: serverTimestamp(), updatedAt: serverTimestamp() }));
});
test('an expired fast can complete and then stays locked', async () => {
  await seed('fastingSessions/s', session('s', 'alice', { startTime: ago(73), createdAt: ago(73) }));
  const ref = doc(db('alice'), 'fastingSessions', 's');
  await assertSucceeds(updateDoc(ref, { status: 'completed', elapsedSeconds: 259200, endTime: serverTimestamp(), updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(ref, { status: 'active', updatedAt: serverTimestamp() }));
});
test('owner can stop a session; stopped sessions stay locked', async () => {
  await seed('fastingSessions/s', session('s', 'alice', { startTime: ago(1), createdAt: ago(1) }));
  const ref = doc(db('alice'), 'fastingSessions', 's');
  await assertSucceeds(updateDoc(ref, { status: 'stopped', elapsedSeconds: 3600, endTime: serverTimestamp(), updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(ref, { status: 'active', updatedAt: serverTimestamp() }));
});
test('other users cannot stop or change an owned session', async () => {
  await seed('fastingSessions/s', session('s', 'alice', { startTime: ago(1), createdAt: ago(1) }));
  await assertFails(updateDoc(doc(db('bob'), 'fastingSessions', 's'), { status: 'stopped', elapsedSeconds: 3600, endTime: serverTimestamp(), updatedAt: serverTimestamp() }));
});
test('session start time cannot be changed later', async () => {
  await seed('fastingSessions/s', session('s', 'alice', { startTime: ago(1), createdAt: ago(1) }));
  await assertFails(updateDoc(doc(db('alice'), 'fastingSessions', 's'), { startTime: ago(73), status: 'completed', elapsedSeconds: 259200, endTime: serverTimestamp(), updatedAt: serverTimestamp() }));
});
test('profile is private to its owner', async () => {
  const data = { id: 'alice', displayName: 'Alice', avatarColor: '#0A84FF', countryFlag: '🏁', premiumUnlocked: true, createdAt: serverTimestamp(), updatedAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(db('alice'), 'users', 'alice'), data));
  await assertFails(getDoc(doc(db('bob'), 'users', 'alice')));
});
test('contest creation cannot enroll another user without their action', async () => {
  await assertFails(setDoc(doc(db('alice'), 'contests', 'c'), contest('c', 'alice', { participantIds: ['alice', 'bob'] })));
  await assertSucceeds(setDoc(doc(db('alice'), 'contests', 'c'), contest('c', 'alice')));
});
test('users can join and leave only themselves', async () => {
  await seed('contests/c', contest('c', 'alice'));
  const ref = doc(db('bob'), 'contests', 'c');
  await assertSucceeds(updateDoc(ref, { participantIds: ['alice', 'bob'], updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(ref, { participantIds: ['alice', 'bob', 'charlie'], updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(ref, { participantIds: ['alice', 'bob', 'bob'], updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(ref, { participantIds: ['alice'], updatedAt: serverTimestamp() }));
});
test('only contest members can create contest sessions', async () => {
  await seed('contests/c', contest('c', 'alice'));
  await assertFails(setDoc(doc(db('bob'), 'fastingSessions', 's'), session('s', 'bob', { contestId: 'c' })));
  await assertSucceeds(setDoc(doc(db('alice'), 'fastingSessions', 's'), session('s', 'alice', { contestId: 'c' })));
});
test('deleting a contest does not prevent its participant stopping an existing session', async () => {
  await seed('fastingSessions/s', session('s', 'alice', { startTime: ago(1), createdAt: ago(1), contestId: 'deleted-contest' }));
  await assertSucceeds(updateDoc(doc(db('alice'), 'fastingSessions', 's'), { status: 'stopped', elapsedSeconds: 3600, endTime: serverTimestamp(), updatedAt: serverTimestamp() }));
});
