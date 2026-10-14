import {
  MAX_TRANSLATE_TEXTS,
  MAX_TRANSLATE_TEXT_CHARS,
  MAX_WORD_CHARS,
  translateCallCap,
} from './config.js';
import { authenticate } from './auth.js';
import { HttpError, forwardJson, sendError } from './http.js';
import { refund, reserve, resolveDay } from './usage.js';

const SOURCE_LANGS = ['EN', 'TR'];
const TARGET_LANGS = ['TR', 'EN', 'EN-US', 'EN-GB'];
const DICTIONARY_LANGS = ['en', 'tr'];

export function validateDeeplRequest(body) {
  const { text, source_lang: sourceLang, target_lang: targetLang } = body ?? {};
  if (!Array.isArray(text) || text.length === 0 || text.length > MAX_TRANSLATE_TEXTS
    || text.some((t) => typeof t !== 'string' || t.length > MAX_TRANSLATE_TEXT_CHARS)) {
    throw new HttpError(400, 'INVALID_ARGUMENT', 'Metin geçersiz.');
  }
  if (!SOURCE_LANGS.includes(sourceLang) || !TARGET_LANGS.includes(targetLang)) {
    throw new HttpError(400, 'INVALID_ARGUMENT', 'Dil geçersiz.');
  }
  return { text, source_lang: sourceLang, target_lang: targetLang };
}

export function validateWord(word) {
  if (typeof word !== 'string' || word.trim().length === 0 || word.length > MAX_WORD_CHARS) {
    throw new HttpError(400, 'INVALID_ARGUMENT', 'Kelime geçersiz.');
  }
  return word.trim();
}

/** Ücretsiz DeepL anahtarları ":fx" ile biter ve ayrı adrese gider. */
export function deeplUrl(key) {
  return key.endsWith(':fx')
    ? 'https://api-free.deepl.com/v2/translate'
    : 'https://api.deepl.com/v2/translate';
}

/**
 * Çeviri işlevi (eski Vercel vekil sunucusunun yerine):
 * - `POST /deepl`       — DeepL çevirisi (gövde DeepL'in biçiminde).
 * - `GET  /dictionary`  — Google sözlük anlamları (`sl`, `tl`, `word`).
 * - `GET  /image`       — Pexels kelime görseli (`word`).
 * Cevaplar servislerin kendi biçiminde aynen iletilir. Her istek Firebase
 * oturumuyla doğrulanır; kullanıcı başına günlük istek tavanı vardır.
 */
export function createTranslateHandler({ auth, db, fetchFn = fetch, deeplKey, pexelsKey, now = () => new Date(), logger = console }) {
  return async (req, res) => {
    try {
      const user = await authenticate(req, auth);
      const day = resolveDay(req.method === 'GET' ? req.query?.date : req.body?.date, now());
      const cap = translateCallCap(user.plan);

      let request;
      if (req.method === 'POST' && req.path === '/deepl') {
        const body = validateDeeplRequest(req.body);
        const key = deeplKey();
        request = () => fetchFn(deeplUrl(key), {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `DeepL-Auth-Key ${key}` },
          body: JSON.stringify(body),
        });
      } else if (req.method === 'GET' && req.path === '/dictionary') {
        const { sl, tl } = req.query ?? {};
        if (!DICTIONARY_LANGS.includes(sl) || !DICTIONARY_LANGS.includes(tl)) {
          throw new HttpError(400, 'INVALID_ARGUMENT', 'Dil geçersiz.');
        }
        const word = validateWord(req.query?.word);
        const url = 'https://translate.googleapis.com/translate_a/single?client=gtx'
          + `&sl=${sl}&tl=${tl}&dt=t&dt=bd&q=${encodeURIComponent(word)}`;
        request = () => fetchFn(url);
      } else if (req.method === 'GET' && req.path === '/image') {
        const word = validateWord(req.query?.word);
        const url = `https://api.pexels.com/v1/search?per_page=1&query=${encodeURIComponent(word)}`;
        request = () => fetchFn(url, { headers: { Authorization: pexelsKey() } });
      } else {
        throw new HttpError(404, 'NOT_FOUND', 'Bulunamadı.');
      }

      if (!(await reserve(db, user.uid, day, 'translateCalls', cap))) {
        throw new HttpError(429, 'LIMIT_REACHED', 'Günlük çeviri isteği sınırına ulaşıldı.');
      }
      let upstream;
      try {
        upstream = await request();
      } catch (error) {
        await refund(db, user.uid, 'translateCalls', cap);
        throw error;
      }
      await forwardJson(res, upstream);
    } catch (error) {
      if (!(error instanceof HttpError)) logger.error('translate işlevi hatası', error);
      sendError(res, error);
    }
  };
}
