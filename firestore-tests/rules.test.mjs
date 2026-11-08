// Emulator-only tests: the "demo-" project ID cannot reach a real Firebase project.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, collectionGroup, deleteDoc, doc, getDoc, getDocs, setDoc } from 'firebase/firestore';

const ALICE = 'alice-uid';
const BOB = 'bob-uid';
// AddSubjectDialog uses DateTime.now().toString() as the ID; addSubject uses a UUID.
const DIALOG_ID = '2026-11-08 22:43:11.123456';
const UUID_ID = '3f1c2b9a-7d4e-4c1a-9b2f-1a2b3c4d5e6f';

/** The same shape as Subject.toMap(). */
const subject = (id, changes = {}) => ({
  id,
  name: 'Algorithms',
  colorValue: 4283215696,
  createdDate: '2026-11-08T22:43:11.123456',
  weightage: 20,
  dueDate: null,
  dueTime: null,
  priority: null,
  notes: null,
  ...changes,
});
const without = (data, field) => {
  const copy = { ...data };
  delete copy[field];
  return copy;
};

let env;
const asUser = (uid) => env.authenticatedContext(uid).firestore();
const asGuest = () => env.unauthenticatedContext().firestore();
const seed = (path, data) => env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), path), data));
const aliceSubject = (id = UUID_ID) => doc(asUser(ALICE), `users/${ALICE}/subjects/${id}`);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-studypilot-rules',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
beforeEach(() => env.clearFirestore());
after(() => env.cleanup());

describe('owner access (what the app does)', () => {
  it('syncs: lists their own subjects', async () => {
    await seed(`users/${ALICE}/subjects/${UUID_ID}`, subject(UUID_ID));
    await assertSucceeds(getDocs(collection(asUser(ALICE), `users/${ALICE}/subjects`)));
  });
  it('reads one of their own subjects', async () => {
    await seed(`users/${ALICE}/subjects/${UUID_ID}`, subject(UUID_ID));
    await assertSucceeds(getDoc(aliceSubject()));
  });
  it('creates a subject with empty optional fields', () => assertSucceeds(setDoc(aliceSubject(), subject(UUID_ID))));
  it('creates a subject with every field filled', () =>
    assertSucceeds(setDoc(aliceSubject(), subject(UUID_ID, {
      dueDate: '2026-12-01T00:00:00.000', dueTime: '09:30', priority: 'urgentImportant', notes: 'Chapter 4',
    }))));
  it('accepts the dialog timestamp ID', () => assertSucceeds(setDoc(aliceSubject(DIALOG_ID), subject(DIALOG_ID))));
  it('accepts an empty notes string', () => assertSucceeds(setDoc(aliceSubject(), subject(UUID_ID, { notes: '' }))));
  it('overwrites an existing subject', async () => {
    await seed(`users/${ALICE}/subjects/${UUID_ID}`, subject(UUID_ID));
    await assertSucceeds(setDoc(aliceSubject(), subject(UUID_ID, { name: 'Renamed', colorValue: 1 })));
  });
  it('deletes a subject', async () => {
    await seed(`users/${ALICE}/subjects/${UUID_ID}`, subject(UUID_ID));
    await assertSucceeds(deleteDoc(aliceSubject()));
  });
  it('can still read and delete an older document that fails validation', async () => {
    await seed(`users/${ALICE}/subjects/old`, { name: '', legacyField: true });
    await assertSucceeds(getDoc(aliceSubject('old')));
    await assertSucceeds(deleteDoc(aliceSubject('old')));
  });
});

describe('other users and signed-out access', () => {
  const path = `users/${ALICE}/subjects/${UUID_ID}`;
  beforeEach(() => seed(path, subject(UUID_ID)));

  it('signed out: cannot read', () => assertFails(getDoc(doc(asGuest(), path))));
  it('signed out: cannot list', () => assertFails(getDocs(collection(asGuest(), `users/${ALICE}/subjects`))));
  it('signed out: cannot write', () => assertFails(setDoc(doc(asGuest(), path), subject(UUID_ID))));
  it('signed out: cannot delete', () => assertFails(deleteDoc(doc(asGuest(), path))));
  it('another user: cannot read', () => assertFails(getDoc(doc(asUser(BOB), path))));
  it('another user: cannot list', () => assertFails(getDocs(collection(asUser(BOB), `users/${ALICE}/subjects`))));
  it('another user: cannot overwrite', () => assertFails(setDoc(doc(asUser(BOB), path), subject(UUID_ID))));
  it('another user: cannot delete', () => assertFails(deleteDoc(doc(asUser(BOB), path))));
  it('another user: cannot create in someone else\'s path', () =>
    assertFails(setDoc(doc(asUser(BOB), `users/${ALICE}/subjects/new`), subject('new'))));
  it('nobody can query all users\' subjects at once', () =>
    assertFails(getDocs(collectionGroup(asUser(ALICE), 'subjects'))));
});

describe('invalid subject data', () => {
  const rejects = (name, data) => it(name, () => assertFails(setDoc(aliceSubject(), data)));
  const ok = subject(UUID_ID);

  rejects('ID that differs from the document ID', subject('different-id'));
  rejects('extra field', { ...ok, isAdmin: true });
  for (const field of ['id', 'name', 'colorValue', 'createdDate', 'weightage']) {
    rejects(`missing required field: ${field}`, without(ok, field));
  }
  rejects('empty name', subject(UUID_ID, { name: '' }));
  rejects('name over 500 characters', subject(UUID_ID, { name: 'x'.repeat(501) }));
  rejects('non-text name', subject(UUID_ID, { name: 42 }));
  rejects('non-integer colorValue', subject(UUID_ID, { colorValue: '#fff' }));
  rejects('fractional weightage', subject(UUID_ID, { weightage: 20.5 }));
  rejects('non-text createdDate', subject(UUID_ID, { createdDate: 1234 }));
  for (const field of ['dueDate', 'dueTime', 'priority', 'notes']) {
    rejects(`non-text optional field: ${field}`, subject(UUID_ID, { [field]: 7 }));
  }
  it('rejects the same invalid data on update', async () => {
    await seed(`users/${ALICE}/subjects/${UUID_ID}`, ok);
    await assertFails(setDoc(aliceSubject(), { ...ok, name: '' }));
  });
});

describe('everything else stays denied', () => {
  const denied = [
    `users/${ALICE}`,
    `users/${ALICE}/notes/n1`,
    `users/${ALICE}/subjects/s1/chapters/c1`,
    'subjects/s1',
    'workspaces/w1',
    'workspaces/w1/tasks/t1',
    'projects/p1',
  ];
  for (const path of denied) {
    it(`signed-in user cannot read ${path}`, () => assertFails(getDoc(doc(asUser(ALICE), path))));
    it(`signed-in user cannot write ${path}`, () => assertFails(setDoc(doc(asUser(ALICE), path), { a: 1 })));
  }
});
