import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ingilizce_destek_app/services/subscription_service.dart';

/// Limitler hem uygulamada hem sunucuda (functions/src/limits.json) tanımlı.
/// Biri değişip diğeri unutulursa sunucu, uygulamanın izin verdiği bir
/// isteği reddeder; bu test iki tablonun aynı olmasını garanti eder.
void main() {
  test('uygulama ve sunucu limitleri aynı', () {
    final json = jsonDecode(File('functions/src/limits.json').readAsStringSync()) as Map<String, dynamic>;
    final server = json.map(
      (plan, values) => MapEntry(plan, Map<String, int>.from(values as Map)),
    );
    expect(server, SubscriptionService.limits);
  });
}
