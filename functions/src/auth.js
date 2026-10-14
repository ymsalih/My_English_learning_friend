import { HttpError } from './http.js';

/**
 * Paket, RevenueCat eklentisinin hesaba koyduğu "revenueCatEntitlements"
 * etiketinden okunur (kullanıcı değiştiremez). Öncelik uygulamadaki
 * `syncRevenueCatStatus` ve Firestore kurallarıyla aynı.
 */
export function planFromClaims(claims) {
  const entitlements = Array.isArray(claims?.revenueCatEntitlements)
    ? claims.revenueCatEntitlements
    : [];
  if (entitlements.includes('max')) return 'max';
  if (entitlements.includes('pro')) return 'pro';
  if (entitlements.includes('plus') || entitlements.includes('premium')) return 'plus';
  return 'basic';
}

/**
 * İstekteki Firebase oturum kimliğini (ID token) doğrular.
 * Giriş yapmamış istekler 401 ile reddedilir.
 */
export async function authenticate(req, auth) {
  const header = req.get('authorization') ?? '';
  const match = header.match(/^Bearer (.+)$/);
  if (!match) {
    throw new HttpError(401, 'UNAUTHENTICATED', 'Giriş yapılmamış.');
  }
  let decoded;
  try {
    decoded = await auth.verifyIdToken(match[1]);
  } catch {
    throw new HttpError(401, 'UNAUTHENTICATED', 'Oturum doğrulanamadı.');
  }
  return { uid: decoded.uid, plan: planFromClaims(decoded) };
}
