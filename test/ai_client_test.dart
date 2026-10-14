import 'package:flutter_test/flutter_test.dart';
import 'package:ingilizce_destek_app/services/ai_client.dart';

void main() {
  test('sohbet isteği yalnızca seçenekleri ve mesajı içerir (talimat sunucuda)', () {
    final request = AiClient.chatRequest(
      mode: 'Gramer',
      level: 'B1',
      history: [AiClient.userContent('Hello'), AiClient.modelContent('Hi!')],
      message: 'I goes school',
      date: '2026-10-14',
    );
    expect(request, {
      'mode': 'Gramer',
      'level': 'B1',
      'history': [
        {'role': 'user', 'text': 'Hello'},
        {'role': 'model', 'text': 'Hi!'},
      ],
      'message': 'I goes school',
      'date': '2026-10-14',
    });
    expect(request.containsKey('systemInstruction'), isFalse);
  });

  test('cevaptan düşünce parçaları hariç metin okunur', () {
    expect(
      AiClient.textOf({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'düşünce', 'thought': true},
                {'text': '{"reply":'},
                {'text': '"Hi"}'},
              ],
            },
          },
        ],
      }),
      '{"reply":"Hi"}',
    );
    expect(AiClient.textOf({'candidates': []}), '');
  });

  test('engellenen istek BLOCKED hatası verir', () {
    expect(
      () => AiClient.textOf({
        'promptFeedback': {'blockReason': 'SAFETY'},
      }),
      throwsA(isA<AiException>().having((e) => e.status, 'status', 'BLOCKED')),
    );
  });

  test('sunucu hataları anlaşılır Türkçe mesaja çevrilir', () {
    expect(
      AiClient.userMessage(AiException('x', statusCode: 403, status: 'LIMIT_REACHED')),
      contains('hakkın doldu'),
    );
    expect(
      AiClient.userMessage(AiException('x', statusCode: 401, status: 'UNAUTHENTICATED')),
      contains('Oturumun'),
    );
    expect(
      AiClient.userMessage(AiException('x', statusCode: 429, status: 'RESOURCE_EXHAUSTED')),
      contains('yoğun'),
    );
  });

  test('günlük hak dolması ve oturum hatası tekrar denenmez; yoğunluk denenir', () {
    expect(AiClient.isRetryable(AiException('x', statusCode: 403, status: 'LIMIT_REACHED')), isFalse);
    expect(AiClient.isRetryable(AiException('x', statusCode: 401, status: 'UNAUTHENTICATED')), isFalse);
    expect(AiClient.isRetryable(AiException('x', statusCode: 503)), isTrue);
  });
}
