import assert from 'node:assert/strict';
import { test } from 'node:test';

import { authenticate, planFromClaims } from '../src/auth.js';
import { LIMITS, translateCallCap } from '../src/config.js';
import { HttpError } from '../src/http.js';
import { refund, reserve, resolveDay } from '../src/usage.js';
import { fakeAuth, fakeDb, fakeReq } from './helpers.js';

test('paket, RevenueCat etiketinden uygulamadaki öncelikle okunur', () => {
  assert.equal(planFromClaims({}), 'basic');
  assert.equal(planFromClaims({ revenueCatEntitlements: ['plus'] }), 'plus');
  assert.equal(planFromClaims({ revenueCatEntitlements: ['premium'] }), 'plus');
  assert.equal(planFromClaims({ revenueCatEntitlements: ['pro', 'plus'] }), 'pro');
  assert.equal(planFromClaims({ revenueCatEntitlements: ['max', 'pro'] }), 'max');
  assert.equal(planFromClaims({ revenueCatEntitlements: 'max' }), 'basic');
});

test('giriş yapılmamış veya geçersiz oturum 401 alır', async () => {
  const auth = fakeAuth({ good: { uid: 'u1', revenueCatEntitlements: ['pro'] } });
  await assert.rejects(authenticate(fakeReq(), auth), (e) => e instanceof HttpError && e.code === 401);
  await assert.rejects(authenticate(fakeReq({ token: 'bad' }), auth), (e) => e.code === 401);
  assert.deepEqual(await authenticate(fakeReq({ token: 'good' }), auth), { uid: 'u1', plan: 'pro' });
});

test('gün: uygulamanın yerel tarihi en fazla 1 gün farkla kabul edilir', () => {
  const now = new Date('2026-10-14T22:30:00Z');
  assert.equal(resolveDay('2026-10-15', now), '2026-10-15');
  assert.equal(resolveDay('2026-10-13', now), '2026-10-13');
  assert.equal(resolveDay('2026-10-20', now), '2026-10-14');
  assert.equal(resolveDay('saçma', now), '2026-10-14');
  assert.equal(resolveDay(undefined, now), '2026-10-14');
});

test('hak ayırma limitte durur, yeni günde sıfırlanır', async () => {
  const db = fakeDb();
  assert.equal(await reserve(db, 'u1', '2026-10-14', 'chat', 2), true);
  assert.equal(await reserve(db, 'u1', '2026-10-14', 'chat', 2), true);
  assert.equal(await reserve(db, 'u1', '2026-10-14', 'chat', 2), false);
  assert.equal(db.docs.get('server_usage/u1').counts.chat, 2);

  assert.equal(await reserve(db, 'u1', '2026-10-15', 'chat', 2), true);
  assert.equal(db.docs.get('server_usage/u1').day, '2026-10-15');
  assert.equal(db.docs.get('server_usage/u1').counts.chat, 1);
});

test('tarih geri giderse kayıtlı gün geçerli kalır (sayaç sıfırlanmaz)', async () => {
  const db = fakeDb({ 'server_usage/u1': { day: '2026-10-15', counts: { chat: 2 } } });
  assert.equal(await reserve(db, 'u1', '2026-10-14', 'chat', 2), false);
  assert.equal(db.docs.get('server_usage/u1').day, '2026-10-15');
});

test('sayaçlar birbirinden bağımsız; sınırsız haklar sayılmaz', async () => {
  const db = fakeDb();
  await reserve(db, 'u1', '2026-10-14', 'chat', 5);
  await reserve(db, 'u1', '2026-10-14', 'storyGen', 5);
  assert.deepEqual(db.docs.get('server_usage/u1').counts, { chat: 1, storyGen: 1 });
  assert.equal(await reserve(db, 'u2', '2026-10-14', 'chat', 999999), true);
  assert.equal(db.docs.has('server_usage/u2'), false);
});

test('iade sayacı bir azaltır, sıfırın altına inmez', async () => {
  const db = fakeDb({ 'server_usage/u1': { day: '2026-10-14', counts: { chat: 1 } } });
  await refund(db, 'u1', 'chat', 5);
  assert.equal(db.docs.get('server_usage/u1').counts.chat, 0);
  await refund(db, 'u1', 'chat', 5);
  assert.equal(db.docs.get('server_usage/u1').counts.chat, 0);
  await refund(db, 'nobody', 'chat', 5);
});

test('limit tablosu dört paketi içerir; çeviri isteği tavanı', () => {
  assert.deepEqual(Object.keys(LIMITS), ['basic', 'plus', 'pro', 'max']);
  assert.equal(translateCallCap('basic'), LIMITS.basic.translateCount * 15);
  assert.equal(translateCallCap('max'), 5000);
  assert.equal(translateCallCap('bilinmeyen'), LIMITS.basic.translateCount * 15);
});
