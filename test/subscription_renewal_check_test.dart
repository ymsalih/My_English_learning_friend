import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:ingilizce_destek_app/services/subscription_renewal_check.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  test('RevenueCat yönetim adresi varsa o kullanılır', () {
    const check = RenewalCheck(
      RenewalStatus.renewing,
      store: Store.playStore,
      managementUrl: 'https://play.google.com/store/account/subscriptions?sku=pro',
    );
    expect(check.manageUrl, 'https://play.google.com/store/account/subscriptions?sku=pro');
  });

  test('adres yoksa aboneliğin alındığı mağazanın sayfası açılır', () {
    const play = RenewalCheck(RenewalStatus.renewing, store: Store.playStore);
    const apple = RenewalCheck(RenewalStatus.renewing, store: Store.appStore);
    expect(play.manageUrl, 'https://play.google.com/store/account/subscriptions');
    expect(apple.manageUrl, 'https://apps.apple.com/account/subscriptions');
    expect(apple.isAppleStore, isTrue);
    expect(play.isAppleStore, isFalse);
  });

  test('abonelik yalnızca alındığı platformda "bu cihazın mağazası" sayılır', () {
    const play = RenewalCheck(RenewalStatus.renewing, store: Store.playStore);
    const apple = RenewalCheck(RenewalStatus.renewing, store: Store.appStore);
    expect(apple.isFromThisPlatform, Platform.isIOS);
    expect(play.isFromThisPlatform, !Platform.isIOS);
  });
}
