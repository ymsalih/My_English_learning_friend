/**
 * Uygulamaya dönen hatalar Gemini'nin hata biçimindedir:
 * `{"error": {"code": 403, "status": "...", "message": "..."}}`.
 * Böylece uygulamadaki mevcut hata işleme aynen çalışır.
 */
export class HttpError extends Error {
  constructor(code, status, message) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

export function sendError(res, error) {
  if (res.headersSent) {
    res.end();
    return;
  }
  const isKnown = error instanceof HttpError;
  const code = isKnown ? error.code : 500;
  const status = isKnown ? error.status : 'INTERNAL';
  const message = isKnown ? error.message : 'Sunucu hatası.';
  res.status(code).json({ error: { code, status, message } });
}

/** Yukarı akıştaki (Gemini, DeepL...) cevabı durum koduyla aynen iletir. */
export async function forwardJson(res, upstream) {
  const body = await upstream.text();
  res.status(upstream.status);
  res.set('Content-Type', upstream.headers.get('content-type') ?? 'application/json; charset=utf-8');
  res.send(body);
}
