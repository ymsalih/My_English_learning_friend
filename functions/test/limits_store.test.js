import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createAiHandler } from '../src/ai.js';
import { LIMITS } from '../src/config.js';
import { LIMITS_DOC, createLimitsProvider, mergeLimits } from '../src/limitsStore.js';
import { fakeAuth, fakeDb, fakeFetch, fakeReq, fakeRes, silentLogger, sseResponse } from './helpers.js';

test('belge yoksa varsayılanlar kullanılır ve belge oluşturulur', async () => {
  const db = fakeDb();
  const getLimits = createLimitsProvider(db, { logger: silentLogger });
  assert.deepEqual(await getLimits(), LIMITS);
  assert.deepEqual(db.docs.get(LIMITS_DOC), LIMITS);
});

test('Console\'daki değerler varsayılanların üzerine yazılır', async () => {
  const db = fakeDb({ [LIMITS_DOC]: { basic: { chatMsgCount: 9 }, max: { storyGenCount: 12 } } });
  const limits = await createLimitsProvider(db, { logger: silentLogger })();
  assert.equal(limits.basic.chatMsgCount, 9);
  assert.equal(limits.max.storyGenCount, 12);
  assert.equal(limits.basic.storyGenCount, LIMITS.basic.storyGenCount);
  assert.equal(limits.pro.chatMsgCount, LIMITS.pro.chatMsgCount);
});

test('hatalı değerler (metin, negatif, ondalık, bilinmeyen alan) yok sayılır', () => {
  const merged = mergeLimits(LIMITS, {
    basic: { chatMsgCount: '10', storyGenCount: -1, translateCount: 2.5, yeniAlan: 5 },
    plus: 'bozuk',
    gold: { chatMsgCount: 99 },
  });
  assert.deepEqual(merged, LIMITS);
});

test('limitler birkaç dakika önbellekte tutulur', async () => {
  let clock = 0;
  const db = fakeDb({ [LIMITS_DOC]: { basic: { chatMsgCount: 9 } } });
  const getLimits = createLimitsProvider(db, { now: () => clock, logger: silentLogger });
  await getLimits();
  await getLimits();
  assert.equal(db.reads, 1);
  clock += 6 * 60 * 1000;
  db.docs.set(LIMITS_DOC, { basic: { chatMsgCount: 3 } });
  assert.equal((await getLimits()).basic.chatMsgCount, 3);
  assert.equal(db.reads, 2);
});

test('Firestore okunamazsa varsayılanlarla devam edilir', async () => {
  const db = fakeDb({}, { failReads: true });
  assert.deepEqual(await createLimitsProvider(db, { logger: silentLogger })(), LIMITS);
});

test('sunucu Console\'da değiştirilen limiti uygular', async () => {
  const db = fakeDb({ [LIMITS_DOC]: { basic: { chatMsgCount: 1 } } });
  const run = createAiHandler({
    auth: fakeAuth({ free: { uid: 'u1' } }),
    db,
    getLimits: createLimitsProvider(db, { logger: silentLogger }),
    fetchFn: fakeFetch(() => sseResponse(['{}'])),
    geminiKey: () => 'K',
    now: () => new Date('2026-10-14T10:00:00Z'),
    logger: silentLogger,
  });
  const body = { message: 'hi', date: '2026-10-14' };
  const first = fakeRes();
  await run(fakeReq({ token: 'free', path: '/chat', body }), first);
  assert.equal(first.statusCode, 200);
  const second = fakeRes();
  await run(fakeReq({ token: 'free', path: '/chat', body }), second);
  assert.equal(second.statusCode, 403);
});

test('ping limitleri önbelleğe alır (giriş istemez)', async () => {
  const db = fakeDb();
  const run = createAiHandler({
    auth: fakeAuth(), db, getLimits: createLimitsProvider(db, { logger: silentLogger }),
    fetchFn: fakeFetch(() => assert.fail('çağrılmamalı')), geminiKey: () => 'K', logger: silentLogger,
  });
  const res = fakeRes();
  await run(fakeReq({ method: 'GET', path: '/ping' }), res);
  assert.equal(res.statusCode, 204);
  assert.equal(db.reads, 1);
});
