import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);

/**
 * Varsayılan paket limitleri (Firestore'daki `config/limits` belgesi yoksa
 * veya okunamazsa). Uygulamadaki `SubscriptionService.defaultLimits` ile
 * birebir aynı olmalı; `test/limits_sync_test.dart` iki tabloyu karşılaştırır.
 */
export const LIMITS = require('./limits.json');

export const UNLIMITED = 999999;

/** Sunucu işlevlerinin bölgesi (RevenueCat eklentisiyle aynı, Türkiye'ye yakın). */
export const REGION = 'europe-west1';

export const GEMINI_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/models';

/** Sohbet: en hızlı model, düşünme "minimal". */
export const CHAT_MODEL = 'gemini-3.5-flash-lite';

/** Hikaye üretimi: daha güçlü model (havuza kaydedildiği için nadiren çalışır). */
export const STORY_MODEL = 'gemini-3.7-flash';

/** Uygulamadaki seçeneklerle aynı (chat_screen / story_screen). */
export const CHAT_MODES = ['Serbest', 'Gramer', 'Kelime', 'Günlük', 'İş', 'Seyahat'];
export const STORY_GENRES = ['Macera', 'Gizem', 'Bilim Kurgu', 'Günlük Yaşam', 'Fantastik'];
export const LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

/** İstek boyutu sınırları (kötüye kullanıma karşı). */
export const MAX_CHAT_MESSAGE_CHARS = 1000;
export const MAX_HISTORY_ITEMS = 20;
export const MAX_HISTORY_TEXT_CHARS = 2000;
// Örnek cümleler tek istekte toplu çevrilir (anlam türü başına en fazla 3).
export const MAX_TRANSLATE_TEXTS = 20;
export const MAX_TRANSLATE_TEXT_CHARS = 1000;
export const MAX_WORD_CHARS = 100;

/**
 * Bir çeviri işlemi sunucuya birden fazla istek atar (ana çeviri, örnek
 * cümleler, sözlük, görsel). Kullanıcı başına günlük çeviri isteği tavanı:
 * paketin günlük çeviri hakkının 15 katı, en fazla 5000.
 */
export const TRANSLATE_CALLS_PER_TRANSLATION = 15;
export const MAX_TRANSLATE_CALLS_PER_DAY = 5000;

export function translateCallCap(plan, limits = LIMITS) {
  const perDay = (limits[plan] ?? limits.basic).translateCount;
  return Math.min(perDay * TRANSLATE_CALLS_PER_TRANSLATION, MAX_TRANSLATE_CALLS_PER_DAY);
}
