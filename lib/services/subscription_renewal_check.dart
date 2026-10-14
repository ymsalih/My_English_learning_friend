import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

enum RenewalStatus {
  /// Dönem sonunda yenilenecek (iptal edilmemiş) bir abonelik var.
  renewing,

  /// Abonelik yok ya da iptal edilmiş (dönem sonuna kadar açık kalabilir).
  notRenewing,

  /// Durum doğrulanamadı (internet yok, RevenueCat'e ulaşılamadı vb.).
  unknown,
}

class RenewalCheck {
  const RenewalCheck(this.status, {this.store, this.managementUrl});

  final RenewalStatus status;
  final Store? store;
  final String? managementUrl;

  /// Abonelik, şu an kullanılan cihazın mağazasından mı alınmış?
  bool get isFromThisPlatform {
    if (store == null) return true;
    return Platform.isIOS
        ? store == Store.appStore || store == Store.macAppStore
        : store == Store.playStore;
  }

  bool get isAppleStore => store == Store.appStore || store == Store.macAppStore;

  static const _appleUrl = 'https://apps.apple.com/account/subscriptions';
  static const _playUrl = 'https://play.google.com/store/account/subscriptions';

  /// Aboneliğin alındığı mağazanın yönetim sayfası (RevenueCat'in verdiği
  /// adres öncelikli).
  String get manageUrl {
    final url = managementUrl;
    if (url != null && url.isNotEmpty) return url;
    if (store == Store.playStore) return _playUrl;
    if (isAppleStore) return _appleUrl;
    return Platform.isIOS ? _appleUrl : _playUrl;
  }
}

/// Hesap silmeden önce, kullanıcının yenilenecek bir aboneliği olup olmadığını
/// RevenueCat'ten (önbelleği atlayarak) kontrol eder.
///
/// Apple: "notify them that billing will continue through Apple and ask them
/// to cancel their subscription before continuing". Yalnızca İPTAL durumuna
/// bakılır (iptal edilmiş abonelik için uyarı gösterilmez); uyarı silmeyi
/// engellemez, kullanıcı yine de silmeye devam edebilir.
class SubscriptionRenewalCheck {
  SubscriptionRenewalCheck._();

  static Future<RenewalCheck> check() async {
    try {
      await Purchases.invalidateCustomerInfoCache();
      final info = await Purchases.getCustomerInfo().timeout(const Duration(seconds: 10));
      final renewing = info.entitlements.active.values.where((e) => e.willRenew).toList();
      if (renewing.isEmpty) return const RenewalCheck(RenewalStatus.notRenewing);
      return RenewalCheck(
        RenewalStatus.renewing,
        store: renewing.first.store,
        managementUrl: info.managementURL,
      );
    } catch (e) {
      debugPrint('Abonelik durumu kontrol edilemedi: $e');
      return const RenewalCheck(RenewalStatus.unknown);
    }
  }
}
