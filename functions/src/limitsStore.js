import { LIMITS } from './config.js';

/**
 * Paket limitleri Firestore'daki bu belgeden yönetilir (Firebase Console'dan
 * değiştirilebilir; uygulama güncellemesi gerekmez). Uygulama da aynı belgeyi
 * okur. Belge yoksa veya okunamazsa `limits.json` varsayılanları kullanılır.
 */
export const LIMITS_DOC = 'config/limits';

const CACHE_MS = 60 * 1000;

/**
 * Varsayılanların üzerine belgedeki geçerli değerleri (0 veya pozitif tam
 * sayı) yazar. Eksik, yanlış türde veya bilinmeyen alanlar yok sayılır;
 * böylece Console'daki bir yazım hatası uygulamayı bozmaz.
 */
export function mergeLimits(defaults, data) {
  const merged = {};
  for (const [plan, values] of Object.entries(defaults)) {
    merged[plan] = { ...values };
    const override = data?.[plan];
    if (!override || typeof override !== 'object') continue;
    for (const key of Object.keys(values)) {
      const value = override[key];
      if (Number.isInteger(value) && value >= 0) merged[plan][key] = value;
    }
  }
  return merged;
}

/**
 * Limitleri döndüren fonksiyon üretir. Sonuç bir dakika bellekte tutulur
 * (her istekte Firestore okunmaz); Console'daki değişiklik en geç bu sürede
 * sunucuya yansır. Süre dolunca eldeki değer hemen döner ve yenisi arka
 * planda okunur: hiçbir istek limit okumasını beklemez (yalnızca sunucu
 * örneğinin ilk isteği bekler).
 */
export function createLimitsProvider(db, { now = () => Date.now(), logger = console } = {}) {
  let cached;
  let fetchedAt = 0;
  let inFlight = null;

  async function refresh() {
    try {
      const ref = db.doc(LIMITS_DOC);
      const snap = await ref.get();
      if (snap.exists) {
        cached = mergeLimits(LIMITS, snap.data());
      } else {
        cached = LIMITS;
        // İlk kez: belge oluşturulur ki Console'da düzenlenebilsin.
        await ref.create(LIMITS).catch(() => {});
      }
    } catch (error) {
      logger.error('Limitler okunamadı, varsayılanlar kullanılıyor', error);
      cached ??= LIMITS;
    } finally {
      fetchedAt = now();
    }
    return cached;
  }

  function startRefresh() {
    inFlight ??= refresh().finally(() => {
      inFlight = null;
    });
    return inFlight;
  }

  return async function getLimits() {
    if (!cached) return startRefresh();
    if (now() - fetchedAt >= CACHE_MS) startRefresh();
    return cached;
  };
}
