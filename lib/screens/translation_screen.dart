import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'camera_scanner_screen.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final _textController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  final FocusNode _focusNode = FocusNode();

  // 🎤 Ses Tanıma Değişkenleri
  late stt.SpeechToText _speechToText;
  bool _isListening = false;

  // Çeviri Sonuç Değişkenleri
  String _mainTranslation = "";
  String _wordType = "";
  String _imageUrl = "";

  // 🚀 Cümle içi kullanımları ve anlamları tutacağımız akıllı liste
  List<Map<String, String>> _contextualMeanings = [];

  bool _isLoading = false;
  bool _isEnToTr = true; // true = İngilizce -> Türkçe

  final LinearGradient primaryGradient = LinearGradient(
    colors: [Colors.teal.shade700, Colors.tealAccent.shade700],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- 🛡️ GÜVENLİ API ANAHTARLARI ---
  final String _deepLApiKey = dotenv.env['DEEPL_API_KEY'] ?? "";

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
  }

  @override
  void dispose() {
    if (_isListening) {
      _speechToText.stop();
    }
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  // --- 📸 YENİ: KAMERA OKUYUCUYU AÇMA FONKSİYONU ---
  // --- 📸 KAMERA OKUYUCUYU AÇMA VE DİNLEME FONKSİYONU ---
  Future<void> _openCameraScanner() async {
    // 1. Kamera sayfasına git ve kullanıcının bir kelime bulup dönmesini bekle
    final scannedWord = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraScannerScreen()),
    );

    // 2. Eğer kullanıcı bir kelime bulup onayladıysa (geri döndüyse)
    if (scannedWord != null &&
        scannedWord is String &&
        scannedWord.isNotEmpty) {
      setState(() {
        // Okunan kelimeyi metin kutusuna yaz
        _textController.text = scannedWord;
        // Kameradan hep İngilizce okuyacağımız için çeviri yönünü garantiye alalım (EN -> TR)
        _isEnToTr = true;
      });

      // 3. Hiçbir butona basmasına gerek kalmadan otomatik çeviriyi başlat!
      _translateAndFetchDictionary();
    }
  }

  // --- 🎤 MİKROFON DİNLEME MOTORU ---
  void _listen() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onStatus: (val) => debugPrint('Mikrofon Durumu: $val'),
        onError: (val) => debugPrint('Mikrofon Hatası: $val'),
      );

      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          localeId: _isEnToTr ? 'en_US' : 'tr_TR',
          onResult: (val) {
            setState(() {
              _textController.text = val.recognizedWords;
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
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

    if (_isListening) {
      setState(() => _isListening = false);
      _speechToText.stop();
    }

    setState(() {
      _isLoading = true;
      _mainTranslation = "";
      _wordType = "";
      _contextualMeanings = []; // Listeyi sıfırla
      _imageUrl = "";
    });

    try {
      // DeepL'den ilk çeviriyi al
      String deepLResult = await _translateWithDeepL(textToTranslate);

      // 🚀 SENIOR HACK: Türkçe "at", "on", "in" gibi kelimeleri İngilizce zannetmesini önleme!
      if (!_isEnToTr &&
          deepLResult.toLowerCase() == textToTranslate &&
          !textToTranslate.contains(' ')) {
        // Kelimenin başına "bir" ekleyerek bağlam veriyoruz
        String contextResult = await _translateWithDeepL(
          "bir $textToTranslate",
        );
        contextResult = contextResult.toLowerCase();

        // İngilizce'deki "a", "an", "the" takılarını kırpıyoruz
        if (contextResult.startsWith("a ")) {
          deepLResult = contextResult.substring(2).trim();
        } else if (contextResult.startsWith("an ")) {
          deepLResult = contextResult.substring(3).trim();
        } else if (contextResult.startsWith("the ")) {
          deepLResult = contextResult.substring(4).trim();
        } else {
          deepLResult = contextResult;
        }
      }

      if (deepLResult.isNotEmpty && !deepLResult.contains("Hata")) {
        _mainTranslation =
            deepLResult[0].toUpperCase() + deepLResult.substring(1);
      } else {
        _mainTranslation = deepLResult;
      }

      // Artık elimizde kusursuz bir İngilizce kelime var
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
              final partOfSpeech = _translateWordType(
                meaning['partOfSpeech'] ?? "",
              );
              final definitions = meaning['definitions'] as List<dynamic>;

              for (var def in definitions) {
                // Sadece İngilizce "Örnek cümlesi" olan anlamları alıyoruz
                if (def['example'] != null && _contextualMeanings.length < 3) {
                  final engDef = def['definition'].toString();
                  final engEx = def['example'].toString();

                  final trDef = await _translateWithDeepL(
                    engDef,
                    sourceLang: 'EN',
                    targetLang: 'TR',
                  );
                  final trEx = await _translateWithDeepL(
                    engEx,
                    sourceLang: 'EN',
                    targetLang: 'TR',
                  );

                  if (mounted && !trDef.contains("Hata")) {
                    setState(() {
                      _contextualMeanings.add({
                        'type': partOfSpeech,
                        'trDef': trDef,
                        'engEx': engEx,
                        'trEx': trEx,
                      });
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
    final String pexelsApiKey = dotenv.env['PEXELS_API_KEY'] ?? "";
    if (pexelsApiKey.isEmpty) return;

    try {
      final url = Uri.parse(
        'https://api.pexels.com/v1/search?query=${Uri.encodeComponent(word)}&per_page=1&orientation=landscape',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': pexelsApiKey},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['photos'] != null && data['photos'].isNotEmpty) {
          if (mounted) {
            setState(() {
              _imageUrl = data['photos'][0]['src']['medium'];
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Pexels Görsel Çekme Hatası: $e");
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
                _contextualMeanings = [];
                if (_isListening) _listen();
              });
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
        boxShadow: [
          BoxShadow(
            color: _isListening
                ? Colors.red.shade500.withAlpha(50)
                : Colors.black12,
            blurRadius: _isListening ? 15 : 10,
            spreadRadius: _isListening ? 2 : 0,
          ),
        ],
        border: _isListening
            ? Border.all(color: Colors.red.shade300, width: 2)
            : null,
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
        inputFormatters: _isEnToTr
            ? [FilteringTextInputFormatter.deny(RegExp(r'[çÇğĞıİöÖşŞüÜ]'))]
            : [],
        decoration: InputDecoration(
          hintText: _isListening
              ? (_isEnToTr ? 'Listening...' : 'Dinleniyor...')
              : (_isEnToTr
                    ? 'Type or speak an English word...'
                    : 'Türkçe metin yazın veya konuşun...'),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 📢 SES İKONU
              if (_isEnToTr)
                IconButton(
                  icon: const Icon(Icons.volume_up, color: Colors.teal),
                  onPressed: () => _speak(_textController.text, 'en-US'),
                ),

              // 📸 YENİ: KAMERA İLE OKUMA İKONU (SADECE EN->TR MODUNDA ÇIKABİLİR VEYA İKİSİNDE DE)
              // Ben ikisinde de kalmasını öneriyorum çünkü Türkçe yazıları da okutup İngilizceye çevirmek isteyebilir.
              IconButton(
                icon: Icon(Icons.camera_alt, color: Colors.teal.shade700),
                onPressed: _openCameraScanner,
              ),

              // 🎤 MİKROFON İKONU
              IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.red : Colors.teal.shade400,
                  size: _isListening ? 30 : 26,
                ),
                onPressed: _listen,
              ),

              // ❌ TEMİZLEME İKONU
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () => setState(() {
                  _textController.clear();
                  _mainTranslation = "";
                  _imageUrl = "";
                  _contextualMeanings = [];
                  if (_isListening) _listen();
                }),
              ),
            ],
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
              if (_imageUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      _imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.fill,
                      alignment: Alignment.topCenter,
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
                                        (loadingProgress.expectedTotalBytes ??
                                            1)
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
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
                  if (!_isEnToTr)
                    IconButton(
                      icon: const Icon(Icons.volume_up, color: Colors.teal),
                      onPressed: () => _speak(_mainTranslation, 'en-US'),
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

        if (_contextualMeanings.isNotEmpty)
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
                      Icons.explore_rounded,
                      color: Colors.blue.shade700,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Bağlama Göre Kullanımlar",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                ..._contextualMeanings.map((contextItem) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                contextItem['type'] ?? '',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                contextItem['trDef'] ?? '',
                                style: TextStyle(
                                  color: Colors.blue.shade900,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "\"${contextItem['engEx']}\"",
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          contextItem['trEx'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        if (contextItem != _contextualMeanings.last)
                          const Divider(height: 25, thickness: 0.5),
                      ],
                    ),
                  );
                }),
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
