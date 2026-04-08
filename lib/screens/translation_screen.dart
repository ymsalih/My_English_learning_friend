import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🚀 YENİ: Gizli kasayı okumak için eklendi!

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final _textController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();

  // Kutuya otomatik odaklanmamızı sağlayacak yönetici
  final FocusNode _focusNode = FocusNode();

  // Çeviri Sonuç Değişkenleri
  String _mainTranslation = "";
  String _wordType = "";
  List<String> _differentMeanings = [];
  String _exampleOriginal = "";
  String _exampleTranslated = "";
  String _imageUrl = "";

  bool _isLoading = false;
  bool _isEnToTr = true; // true = İngilizce -> Türkçe

  final LinearGradient primaryGradient = LinearGradient(
    colors: [Colors.teal.shade700, Colors.tealAccent.shade700],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- 🛡️ GÜVENLİ API ANAHTARLARI ---
  // Şifreler artık kodun içinde değil, .env gizli kasasından çekiliyor!
  final String _pixabayApiKey = dotenv.env['PIXABAY_API_KEY'] ?? "";
  final String _deepLApiKey = dotenv.env['DEEPL_API_KEY'] ?? "";

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _speak(String text, String languageCode) async {
    if (text.isEmpty) return;
    await flutterTts.setLanguage(languageCode);
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.speak(text);
  }

  String _translateWordType(String type) {
    switch (type.toLowerCase()) {
      case 'noun':
        return 'İsim';
      case 'verb':
        return 'Fiil';
      case 'adjective':
        return 'Sıfat';
      case 'adverb':
        return 'Zarf';
      case 'pronoun':
        return 'Zamir';
      case 'preposition':
        return 'Edat';
      case 'conjunction':
        return 'Bağlaç';
      case 'interjection':
        return 'Ünlem';
      default:
        return type;
    }
  }

  Future<String> _translateWithDeepL(
    String text, {
    String? sourceLang,
    String? targetLang,
  }) async {
    if (_deepLApiKey.isEmpty) return "Lütfen DeepL API Key girin.";

    final url = Uri.parse('https://api-free.deepl.com/v2/translate');
    final sLang = sourceLang ?? (_isEnToTr ? 'EN' : 'TR');
    final tLang = targetLang ?? (_isEnToTr ? 'TR' : 'EN-US');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'DeepL-Auth-Key $_deepLApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': [text],
          'source_lang': sLang,
          'target_lang': tLang,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['translations'][0]['text'];
      } else {
        debugPrint("DeepL Hatası (${response.statusCode}): ${response.body}");
        return "Çeviri Hatası";
      }
    } catch (e) {
      debugPrint("DeepL Bağlantı Hatası: $e");
      return "Bağlantı Hatası";
    }
  }

  Future<void> _translateAndFetchDictionary() async {
    final textToTranslate = _textController.text.trim().toLowerCase();
    if (textToTranslate.isEmpty) return;

    setState(() {
      _isLoading = true;
      _mainTranslation = "";
      _wordType = "";
      _differentMeanings = [];
      _exampleOriginal = "";
      _exampleTranslated = "";
      _imageUrl = "";
    });

    try {
      final deepLResult = await _translateWithDeepL(textToTranslate);

      if (deepLResult.isNotEmpty && !deepLResult.contains("Hata")) {
        _mainTranslation =
            deepLResult[0].toUpperCase() + deepLResult.substring(1);
      } else {
        _mainTranslation = deepLResult;
      }

      String englishWordToSearch = _isEnToTr
          ? textToTranslate
          : deepLResult.toLowerCase();

      if (!englishWordToSearch.contains(' ')) {
        await _fetchDictionaryData(englishWordToSearch);

        if (_wordType == 'İsim' ||
            _wordType == 'Sıfat' ||
            _wordType == 'Fiil' ||
            _wordType.isEmpty) {
          await _fetchImage(englishWordToSearch);
        }
      }
    } catch (e) {
      debugPrint("Sistem Hatası: $e");
      setState(() {
        _mainTranslation = "Sistemsel bir hata oluştu.";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDictionaryData(String word) async {
    try {
      final url = Uri.parse(
        'https://api.dictionaryapi.dev/api/v2/entries/en/$word',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final meanings = data[0]['meanings'] as List<dynamic>;

          if (meanings.isNotEmpty) {
            _wordType = _translateWordType(meanings[0]['partOfSpeech'] ?? "");

            for (var meaning in meanings) {
              final definitions = meaning['definitions'] as List<dynamic>;
              for (var def in definitions) {
                if (def['definition'] != null &&
                    _differentMeanings.length < 2) {
                  final engDef = def['definition'].toString();
                  final translatedDef = await _translateWithDeepL(
                    engDef,
                    sourceLang: 'EN',
                    targetLang: 'TR',
                  );

                  if (mounted && !translatedDef.contains("Hata")) {
                    setState(() {
                      _differentMeanings.add(translatedDef);
                    });
                  }
                }

                if (def['example'] != null && _exampleOriginal.isEmpty) {
                  _exampleOriginal = def['example'];
                  final exTrans = await _translateWithDeepL(
                    _exampleOriginal,
                    sourceLang: 'EN',
                    targetLang: 'TR',
                  );

                  if (mounted && !exTrans.contains("Hata")) {
                    setState(() {
                      _exampleTranslated = exTrans;
                    });
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Sözlük API Hatası: $e");
    }
  }

  Future<void> _fetchImage(String word) async {
    if (_pixabayApiKey.isEmpty) return;

    try {
      final url = Uri.parse(
        'https://pixabay.com/api/?key=$_pixabayApiKey&q=${Uri.encodeComponent(word)}&image_type=photo&safesearch=true&order=popular&per_page=3',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['hits'] != null && data['hits'].isNotEmpty) {
          if (mounted) {
            setState(() {
              _imageUrl = data['hits'][0]['webformatURL'];
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Görsel Çekme Hatası: $e");
    }
  }

  Future<void> _saveToPool() async {
    if (_textController.text.trim().isEmpty || _mainTranslation.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('words')
        .add({
          'eng': _isEnToTr ? _textController.text.trim() : _mainTranslation,
          'tr': _isEnToTr ? _mainTranslation : _textController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
          'isLearned': false,
        });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Başarıyla eklendi! ✨',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.teal.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Akıllı Çeviri',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: primaryGradient),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade50, Colors.white],
            begin: Alignment.topCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildLanguageSelector(),
              const SizedBox(height: 20),
              _buildInput(),
              const SizedBox(height: 20),
              _buildActionButton(),
              const SizedBox(height: 30),
              _buildResult(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            _isEnToTr ? '🇬🇧 EN' : '🇹🇷 TR',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          IconButton(
            icon: const Icon(
              Icons.swap_horizontal_circle,
              size: 35,
              color: Colors.teal,
            ),
            onPressed: () {
              setState(() {
                _isEnToTr = !_isEnToTr;
                _mainTranslation = "";
                _textController.clear();
                _imageUrl = "";
              });
              // Butona basıldığında imleci tekrar kutuya koyar
              _focusNode.requestFocus();
            },
          ),
          Text(
            _isEnToTr ? '🇹🇷 TR' : '🇬🇧 EN',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: TextField(
        focusNode: _focusNode,
        controller: _textController,
        maxLines: 4,
        minLines: 1,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 18),

        // DİLE GÖRE KLAVYE HARF FİLTRESİ
        inputFormatters: _isEnToTr
            ? [FilteringTextInputFormatter.deny(RegExp(r'[çÇğĞıİöÖşŞüÜ]'))]
            : [],

        decoration: InputDecoration(
          hintText: _isEnToTr
              ? 'Type an English word or text...'
              : 'Türkçe metin veya kelime yazın...',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() {
              _textController.clear();
              _mainTranslation = "";
              _imageUrl = "";
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _translateAndFetchDictionary,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal.shade700,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
              'Akıllı Çeviri ✨',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildResult() {
    if (_mainTranslation.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        if (_imageUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                _imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.teal.shade50,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.teal,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  (loadingProgress.expectedTotalBytes ?? 1)
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.teal.shade200, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '✨ Çeviri Sonucu',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.teal),
                    onPressed: () =>
                        _speak(_mainTranslation, _isEnToTr ? 'tr-TR' : 'en-US'),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 5),
              Text(
                _mainTranslation,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),

              if (_wordType.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bookmark,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _wordType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        if (_differentMeanings.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 15),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue.shade200, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Kelimenin Farklı Anlamları",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._differentMeanings.map(
                  (anlam) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "• ",
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            anlam,
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (_exampleOriginal.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 15),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.orange.shade200, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      color: Colors.orange.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Örnek Cümle",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _exampleOriginal,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _exampleTranslated,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
              ],
            ),
          ),
        const SizedBox(height: 25),

        OutlinedButton.icon(
          onPressed: _saveToPool,
          icon: const Icon(Icons.add_task),
          label: const Text(
            'Bu Kelimeyi Havuzuma Ekle',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 55),
            foregroundColor: Colors.teal.shade700,
            side: BorderSide(color: Colors.teal.shade400, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            backgroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
