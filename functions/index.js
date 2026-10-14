import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { onRequest } from 'firebase-functions/https';
import * as logger from 'firebase-functions/logger';
import { setGlobalOptions } from 'firebase-functions/options';
import { defineSecret } from 'firebase-functions/params';

import { createAiHandler } from './src/ai.js';
import { REGION } from './src/config.js';
import { createLimitsProvider } from './src/limitsStore.js';
import { createTranslateHandler } from './src/translate.js';

initializeApp();
const db = getFirestore();
// Limitler Firestore'daki config/limits belgesinden (birkaç dakika önbellekli).
const getLimits = createLimitsProvider(db, { logger });

// Anahtarlar Google Secret Manager'da durur; uygulamada anahtar yoktur.
const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');
const DEEPL_API_KEY = defineSecret('DEEPL_API_KEY');
const PEXELS_API_KEY = defineSecret('PEXELS_API_KEY');

// maxInstances: beklenmedik bir yük veya kötüye kullanımda faturanın
// kontrolsüz büyümesini önleyen üst sınır (her örnek aynı anda çok sayıda
// isteğe cevap verir).
setGlobalOptions({ region: REGION, maxInstances: 10 });

// cors: uygulamanın web sürümü tarayıcıdan da çağırabilsin (oturum yine zorunlu).
export const ai = onRequest(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 120, memory: '256MiB', cors: true },
  createAiHandler({
    auth: getAuth(),
    db,
    getLimits,
    geminiKey: () => GEMINI_API_KEY.value(),
    logger,
  }),
);

export const translate = onRequest(
  { secrets: [DEEPL_API_KEY, PEXELS_API_KEY], timeoutSeconds: 30, memory: '256MiB', cors: true },
  createTranslateHandler({
    auth: getAuth(),
    db,
    getLimits,
    deeplKey: () => DEEPL_API_KEY.value(),
    pexelsKey: () => PEXELS_API_KEY.value(),
    logger,
  }),
);
