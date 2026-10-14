import 'package:flutter_test/flutter_test.dart';
import 'package:ingilizce_destek_app/services/chat_service.dart';

Map<String, dynamic> _response(String original, String corrected) => {
      'reply': 'Nice!',
      'correction': {
        'original': original,
        'corrected': corrected,
        'explanation': 'Açıklama',
      },
    };

void main() {
  test('yalnızca noktalama farkı olan düzeltme gösterilmez', () {
    final result = ChatService.dropPunctuationOnlyCorrection(
      _response('Yes I like it', 'Yes, I like it.'),
    );
    expect(result['correction']['original'], isEmpty);
    expect(result['correction']['corrected'], isEmpty);
    expect(result['correction']['explanation'], isEmpty);
    expect(result['reply'], 'Nice!');
  });

  test('gerçek gramer hatası düzeltmesi korunur', () {
    final result = ChatService.dropPunctuationOnlyCorrection(
      _response('She go to school', 'She goes to school.'),
    );
    expect(result['correction']['original'], 'She go to school');
    expect(result['correction']['corrected'], 'She goes to school.');
  });

  test("kesme işaretiyle değişen anlam (its / it's) korunur", () {
    final result = ChatService.dropPunctuationOnlyCorrection(
      _response('its raining', "it's raining"),
    );
    expect(result['correction']['original'], 'its raining');
  });

  test('düzeltme yoksa cevap değişmez', () {
    final response = _response('', '');
    expect(ChatService.dropPunctuationOnlyCorrection(response), same(response));
  });
}
