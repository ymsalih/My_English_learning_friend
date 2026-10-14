import {
  CHAT_MODEL,
  CHAT_MODES,
  GEMINI_BASE_URL,
  LEVELS,
  MAX_CHAT_MESSAGE_CHARS,
  MAX_HISTORY_ITEMS,
  MAX_HISTORY_TEXT_CHARS,
  STORY_GENRES,
  STORY_MODEL,
} from './config.js';
import { authenticate } from './auth.js';
import { HttpError, forwardJson, sendError } from './http.js';
import { chatRequestBody, storyRequestBody } from './prompts.js';
import { refund, reserve, resolveDay } from './usage.js';

const LIMIT_REACHED = (what) =>
  new HttpError(403, 'LIMIT_REACHED', `Günlük ${what} hakkın doldu.`);

export function validateChatRequest(body) {
  const { mode, level, message, history } = body ?? {};
  if (typeof message !== 'string' || message.trim().length === 0) {
    throw new HttpError(400, 'INVALID_ARGUMENT', 'Mesaj boş.');
  }
  if (message.length > MAX_CHAT_MESSAGE_CHARS) {
    throw new HttpError(400, 'INVALID_ARGUMENT', 'Mesaj çok uzun.');
  }
  const items = history ?? [];
  if (!Array.isArray(items) || items.length > MAX_HISTORY_ITEMS) {
    throw new HttpError(400, 'INVALID_ARGUMENT', 'Geçmiş geçersiz.');
  }
  for (const item of items) {
    if (!item || (item.role !== 'user' && item.role !== 'model')
      || typeof item.text !== 'string' || item.text.length > MAX_HISTORY_TEXT_CHARS) {
      throw new HttpError(400, 'INVALID_ARGUMENT', 'Geçmiş geçersiz.');
    }
  }
  return {
    mode: CHAT_MODES.includes(mode) ? mode : 'Serbest',
    level: LEVELS.includes(level) ? level : 'A1',
    message: message.trim(),
    history: items.map(({ role, text }) => ({ role, text })),
  };
}

export function validateStoryRequest(body) {
  const { genre, level } = body ?? {};
  if (!STORY_GENRES.includes(genre) || !LEVELS.includes(level)) {
    throw new HttpError(400, 'INVALID_ARGUMENT', 'Tür veya seviye geçersiz.');
  }
  return { genre, level };
}

/**
 * Yapay zeka işlevi:
 * - `GET  /ping`  — bağlantıyı ısıtır (sohbet ekranı açılırken).
 * - `POST /chat`  — sohbet cevabı; Gemini'nin akış (SSE) cevabını aynen iletir.
 * - `POST /story` — hikaye üretimi; Gemini'nin JSON cevabını aynen iletir.
 * Her istek Firebase oturumuyla doğrulanır ve paket limitine göre sayılır.
 * Limitler [getLimits] ile Firestore'daki `config/limits` belgesinden gelir.
 */
export function createAiHandler({
  auth, db, getLimits, fetchFn = fetch, geminiKey, now = () => new Date(), logger = console,
}) {
  return async (req, res) => {
    try {
      if (req.method === 'GET' && req.path === '/ping') {
        // Uyanırken limitleri de önbelleğe alır; ilk mesaj daha hızlı olur.
        await getLimits().catch(() => {});
        res.status(204).end();
        return;
      }
      if (req.method !== 'POST') throw new HttpError(405, 'METHOD_NOT_ALLOWED', 'Yalnızca POST.');

      const user = await authenticate(req, auth);
      const day = resolveDay(req.body?.date, now());
      const table = await getLimits();
      const limits = table[user.plan] ?? table.basic;

      if (req.path === '/chat') {
        const input = validateChatRequest(req.body);
        await handleChat({ res, user, day, input, limit: limits.chatMsgCount });
      } else if (req.path === '/story') {
        const input = validateStoryRequest(req.body);
        await handleStory({ res, user, day, input, limit: limits.storyGenCount });
      } else {
        throw new HttpError(404, 'NOT_FOUND', 'Bulunamadı.');
      }
    } catch (error) {
      if (!(error instanceof HttpError)) logger.error('ai işlevi hatası', error);
      sendError(res, error);
    }
  };

  function geminiRequest(model, method, body) {
    const query = method === 'streamGenerateContent' ? '?alt=sse' : '';
    return fetchFn(`${GEMINI_BASE_URL}/${model}:${method}${query}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': geminiKey() },
      body: JSON.stringify(body),
    });
  }

  async function handleChat({ res, user, day, input, limit }) {
    if (!(await reserve(db, user.uid, day, 'chat', limit))) throw LIMIT_REACHED('sohbet');

    let upstream;
    try {
      upstream = await geminiRequest(CHAT_MODEL, 'streamGenerateContent', chatRequestBody(input));
    } catch (error) {
      await refund(db, user.uid, 'chat', limit);
      throw error;
    }
    if (!upstream.ok) {
      logger.warn(`ai /chat: Gemini ${upstream.status} döndü`);
      await refund(db, user.uid, 'chat', limit);
      await forwardJson(res, upstream);
      return;
    }

    // Cevap geldikçe uygulamaya akıtılır (Gemini'nin SSE biçimi aynen).
    res.status(200);
    res.set('Content-Type', 'text/event-stream; charset=utf-8');
    res.set('Cache-Control', 'no-cache');
    let sentAny = false;
    try {
      for await (const chunk of upstream.body) {
        res.write(chunk);
        sentAny = true;
      }
      res.end();
    } catch (error) {
      // Hiçbir şey gönderilmeden kopan istek sayılmaz (uygulama yeniden dener).
      if (!sentAny) await refund(db, user.uid, 'chat', limit);
      throw error;
    }
  }

  async function handleStory({ res, user, day, input, limit }) {
    if (!(await reserve(db, user.uid, day, 'storyGen', limit))) throw LIMIT_REACHED('hikaye üretme');

    let upstream;
    try {
      upstream = await geminiRequest(STORY_MODEL, 'generateContent', storyRequestBody(input));
    } catch (error) {
      await refund(db, user.uid, 'storyGen', limit);
      throw error;
    }
    if (!upstream.ok) {
      logger.warn(`ai /story: Gemini ${upstream.status} döndü`);
      await refund(db, user.uid, 'storyGen', limit);
    }
    await forwardJson(res, upstream);
  }
}
