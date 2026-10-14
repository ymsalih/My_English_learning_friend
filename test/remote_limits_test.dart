import 'package:flutter_test/flutter_test.dart';
import 'package:ingilizce_destek_app/services/subscription_service.dart';

void main() {
  const defaults = SubscriptionService.defaultLimits;

  test('belge yoksa varsayılanlar geçerli', () {
    expect(SubscriptionService.mergeLimits(defaults, null), defaults);
  });

  test("Console'daki değerler varsayılanların üzerine yazılır", () {
    final merged = SubscriptionService.mergeLimits(defaults, {
      'basic': {'chatMsgCount': 9},
      'max': {'storyGenCount': 12.0},
    });
    expect(merged['basic']!['chatMsgCount'], 9);
    expect(merged['max']!['storyGenCount'], 12);
    expect(merged['basic']!['storyGenCount'], defaults['basic']!['storyGenCount']);
    expect(merged['pro'], defaults['pro']);
  });

  test('hatalı değerler (metin, negatif, ondalık, bilinmeyen alan) yok sayılır', () {
    final merged = SubscriptionService.mergeLimits(defaults, {
      'basic': {'chatMsgCount': '10', 'storyGenCount': -1, 'translateCount': 2.5, 'yeniAlan': 5},
      'plus': 'bozuk',
      'gold': {'chatMsgCount': 99},
    });
    expect(merged, defaults);
  });
}
