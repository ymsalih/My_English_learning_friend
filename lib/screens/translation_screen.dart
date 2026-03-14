import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:translator/translator.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final _textController = TextEditingController();
  final _translator = GoogleTranslator();
  final FlutterTts flutterTts = FlutterTts();

  String _translatedText = "";
  bool _isLoading = false;
  bool _isEnToTr =
      true; // true = İngilizce -> Türkçe, false = Türkçe -> İngilizce

  // Artık sadece içine gönderilen metni İngiliz aksanıyla okuyan genel fonksiyon
  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await flutterTts.setLanguage("en-GB");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.speak(text);
  }

  Future<void> _translate() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _translatedText = "";
    });

    try {
      final translation = await _translator.translate(
        _textController.text.trim(),
        from: _isEnToTr ? 'en' : 'tr',
        to: _isEnToTr ? 'tr' : 'en',
      );

      setState(() {
        _translatedText = translation.text;
      });
    } catch (e) {
      setState(() {
        _translatedText = "Çeviri yapılırken bir hata oluştu.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveToPool() async {
    if (_textController.text.trim().isEmpty || _translatedText.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String engWord = _isEnToTr
          ? _textController.text.trim()
          : _translatedText;
      String trWord = _isEnToTr ? _translatedText : _textController.text.trim();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('words')
          .add({
            'eng': engWord,
            'tr': trWord,
            'timestamp': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kelime başarıyla havuzuna eklendi! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Akıllı Çeviri')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isEnToTr ? 'İngilizce' : 'Türkçe',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.swap_horiz,
                    size: 30,
                    color: Colors.deepPurple,
                  ),
                  onPressed: () {
                    setState(() {
                      _isEnToTr = !_isEnToTr;
                      _translatedText = "";
                      _textController.clear();
                    });
                  },
                ),
                Text(
                  _isEnToTr ? 'Türkçe' : 'İngilizce',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Çevrilecek metni buraya yazın...',
                border: const OutlineInputBorder(),
                // YENİ: Eğer İngilizceden Türkçeye çeviriyorsak, ses butonu BURADA (üstte) çıkacak
                suffixIcon: Row(
                  mainAxisSize:
                      MainAxisSize.min, // İkonların yan yana sığması için
                  children: [
                    if (_isEnToTr)
                      IconButton(
                        icon: const Icon(
                          Icons.volume_up,
                          color: Colors.deepPurple,
                        ),
                        onPressed: () => _speak(_textController.text.trim()),
                        tooltip: 'İngilizce Dinle',
                      ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _textController.clear();
                        setState(() => _translatedText = "");
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _translate,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.translate),
              label: const Text('Çevir', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 30),

            if (_translatedText.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Çeviri Sonucu:',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        // YENİ: Eğer Türkçeden İngilizceye çeviriyorsak, ses butonu BURADA (altta) çıkacak
                        if (!_isEnToTr)
                          IconButton(
                            icon: const Icon(
                              Icons.volume_up,
                              color: Colors.deepPurple,
                              size: 28,
                            ),
                            onPressed: () => _speak(_translatedText),
                            tooltip: 'İngilizce Dinle',
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _translatedText,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: _saveToPool,
                icon: const Icon(Icons.add_task),
                label: const Text('Bu Kelimeyi Havuzuma Ekle'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
