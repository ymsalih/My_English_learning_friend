import { FieldValue } from 'firebase-admin/firestore';
import { UNLIMITED } from './config.js';

/** Sunucunun tuttuğu sayaçlar; istemciler bu koleksiyona erişemez (kural yok). */
export const USAGE_COLLECTION = 'server_usage';

const DAY_MS = 24 * 60 * 60 * 1000;

function utcDay(now) {
  return now.toISOString().slice(0, 10);
}

/**
 * Günlük sayacın günü. Uygulama kullanıcının yerel tarihini gönderir (gün,
 * uygulamadaki sayaçlarla aynı anda sıfırlansın diye). Tarih geçersizse veya
 * sunucunun UTC tarihinden bir günden fazla uzaksa UTC tarihi kullanılır.
 */
export function resolveDay(clientDate, now = new Date()) {
  const utc = utcDay(now);
  if (typeof clientDate === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(clientDate)) {
    const diff = Math.abs(Date.parse(`${clientDate}T00:00:00Z`) - Date.parse(`${utc}T00:00:00Z`));
    if (diff <= DAY_MS) return clientDate;
  }
  return utc;
}

/**
 * Bir hak ayırır: sayaç limitin altındaysa 1 artırır ve `true` döner,
 * değilse `false`. İşlem başarısız olursa `refund` ile geri verilir.
 * Önce ayırıp sonra çağırmak, aynı anda gönderilen isteklerle limitin
 * aşılmasını önler.
 */
export async function reserve(db, uid, day, key, limit) {
  if (limit >= UNLIMITED) return true;
  const ref = db.collection(USAGE_COLLECTION).doc(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : {};
    let effectiveDay = day;
    let counts = {};
    if (data.day === day) {
      counts = data.counts ?? {};
    } else if (typeof data.day === 'string' && day < data.day) {
      // Tarih geri gidemez (ör. saat dilimi değişikliği): kayıtlı gün geçerli.
      effectiveDay = data.day;
      counts = data.counts ?? {};
    }
    const current = Math.max(0, counts[key] ?? 0);
    if (current >= limit) return false;
    tx.set(ref, {
      day: effectiveDay,
      counts: { ...counts, [key]: current + 1 },
      updatedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
}

/** `reserve` ile ayrılan hakkı geri verir (yukarı akış hatası). */
export async function refund(db, uid, key, limit) {
  if (limit >= UNLIMITED) return;
  const ref = db.collection(USAGE_COLLECTION).doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const data = snap.data();
    const current = data.counts?.[key] ?? 0;
    if (current <= 0) return;
    tx.set(ref, { ...data, counts: { ...data.counts, [key]: current - 1 } });
  });
}
