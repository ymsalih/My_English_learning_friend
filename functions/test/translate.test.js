import assert from 'node:assert/strict';
import { test } from 'node:test';

import { translateCallCap } from '../src/config.js';
import { createLimitsProvider } from '../src/limitsStore.js';
import { createTranslateHandler, deeplUrl } from '../src/translate.js';
import {
  fakeAuth, fakeDb, fakeFetch, fakeReq, fakeRes, jsonResponse, silentLogger,
} from './helpers.js';

const NOW = () => new Date('2026-10-14T10:00:00Z');
const auth = fakeAuth({ free: { uid: 'u1' } });

function handler(fetchFn, { db = fakeDb(), deeplKey = 'abc:fx' } = {}) {
  return {
    db,
    run: createTranslateHandler({
      auth, db, getLimits: createLimitsProvider(db, { logger: silentLogger }), fetchFn, deeplKey: () => deeplKey, pexelsKey: () => 'PEXELS', now: NOW, logger: silentLogger,
    }),
  };
}

test('DeepL adresi anahtar türüne göre seçilir', () => {
  assert.equal(deeplUrl('abc:fx'), 'https://api-free.deepl.com/v2/translate');
  assert.equal(deeplUrl('abc'), 'https://api.deepl.com/v2/translate');
});

test('giriş yapılmamış çeviri isteği 401 alır', async () => {
  const fetchFn = fakeFetch(() => assert.fail('çağrılmamalı'));
  const { run } = handler(fetchFn);
  const res = fakeRes();
  await run(fakeReq({ path: '/deepl', body: { text: ['hi'], source_lang: 'EN', target_lang: 'TR' } }), res);
  assert.equal(res.statusCode, 401);
  assert.equal(fetchFn.calls.length, 0);
});

test('DeepL: istek anahtarla gider, cevap aynen döner, istek sayılır', async () => {
  const fetchFn = fakeFetch(() => jsonResponse({ translations: [{ text: 'merhaba' }] }));
  const { run, db } = handler(fetchFn);
  const res = fakeRes();
  await run(fakeReq({ token: 'free', path: '/deepl', body: { text: ['hello'], source_lang: 'EN', target_lang: 'TR' } }), res);
  assert.equal(res.statusCode, 200);
  assert.equal(JSON.parse(res.body).translations[0].text, 'merhaba');
  const call = fetchFn.calls[0];
  assert.equal(call.url, 'https://api-free.deepl.com/v2/translate');
  assert.equal(call.options.headers.Authorization, 'DeepL-Auth-Key abc:fx');
  assert.deepEqual(JSON.parse(call.options.body), { text: ['hello'], source_lang: 'EN', target_lang: 'TR' });
  assert.equal(db.docs.get('server_usage/u1').counts.translateCalls, 1);
});

test('DeepL kota hatası (456) durum koduyla iletilir', async () => {
  const { run } = handler(fakeFetch(() => jsonResponse({ message: 'Quota exceeded' }, 456)));
  const res = fakeRes();
  await run(fakeReq({ token: 'free', path: '/deepl', body: { text: ['a'], source_lang: 'TR', target_lang: 'EN-US' } }), res);
  assert.equal(res.statusCode, 456);
});

test('DeepL: geçersiz gövde 400 alır', async () => {
  const bodies = [
    { text: 'not-array', source_lang: 'EN', target_lang: 'TR' },
    { text: [], source_lang: 'EN', target_lang: 'TR' },
    { text: ['x'.repeat(1001)], source_lang: 'EN', target_lang: 'TR' },
    { text: ['hi'], source_lang: 'DE', target_lang: 'TR' },
  ];
  for (const body of bodies) {
    const { run } = handler(fakeFetch(() => assert.fail('çağrılmamalı')));
    const res = fakeRes();
    await run(fakeReq({ token: 'free', path: '/deepl', body }), res);
    assert.equal(res.statusCode, 400);
  }
});

test('görsel: Pexels anahtarı başlıkta gider', async () => {
  const fetchFn = fakeFetch(() => jsonResponse({ photos: [{ src: { medium: 'https://img' } }] }));
  const { run } = handler(fetchFn);
  const res = fakeRes();
  await run(fakeReq({ method: 'GET', token: 'free', path: '/image', query: { word: 'cat' } }), res);
  assert.equal(res.statusCode, 200);
  assert.equal(fetchFn.calls[0].url, 'https://api.pexels.com/v1/search?per_page=1&query=cat');
  assert.equal(fetchFn.calls[0].options.headers.Authorization, 'PEXELS');
});

test('günlük çeviri isteği tavanına ulaşınca 429 LIMIT_REACHED', async () => {
  const db = fakeDb({ 'server_usage/u1': { day: '2026-10-14', counts: { translateCalls: translateCallCap('basic') } } });
  const fetchFn = fakeFetch(() => assert.fail('çağrılmamalı'));
  const { run } = handler(fetchFn, { db });
  const res = fakeRes();
  await run(fakeReq({ method: 'GET', token: 'free', path: '/image', query: { word: 'cat', date: '2026-10-14' } }), res);
  assert.equal(res.statusCode, 429);
  assert.equal(res.body.error.status, 'LIMIT_REACHED');
});

test('bilinmeyen yol 404', async () => {
  const { run } = handler(fakeFetch(() => assert.fail('çağrılmamalı')));
  const res = fakeRes();
  await run(fakeReq({ method: 'GET', token: 'free', path: '/nope' }), res);
  assert.equal(res.statusCode, 404);
});

test('ping giriş istemeden 204 döner, servis çağrılmaz', async () => {
  const fetchFn = fakeFetch(() => assert.fail('çağrılmamalı'));
  const { run } = handler(fetchFn);
  const res = fakeRes();
  await run(fakeReq({ method: 'GET', path: '/ping' }), res);
  assert.equal(res.statusCode, 204);
  assert.equal(fetchFn.calls.length, 0);
});
