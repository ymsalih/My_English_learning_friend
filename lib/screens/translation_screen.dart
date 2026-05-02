import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'camera_scanner_screen.dart';

// --- VERİ MODELLERİ ---
class WordMeaningGroup {
  final String partOfSpeech;
  final List<String> shortMeanings;
  final List<Map<String, String>> contextualExamples;
  final List<Map<String, List<String>>> reverseMeanings;

  WordMeaningGroup({
    required this.partOfSpeech,
    required this.shortMeanings,
    required this.contextualExamples,
    this.reverseMeanings = const <Map<String, List<String>>>[],
  });
}

class TranslationCacheItem {
  final String originalText;
  final bool isEnToTr;
  final String mainTranslation;
  final String imageUrl;
  final String searchedEnglishWord;
  final List<WordMeaningGroup> groupedMeanings;

  TranslationCacheItem({
    required this.originalText,
    required this.isEnToTr,
    required this.mainTranslation,
    required this.imageUrl,
    required this.searchedEnglishWord,
    required this.groupedMeanings,
  });
}

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final _textController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  final FocusNode _focusNode = FocusNode();

  // 🚀 ADIM 9.8: Tembel başlatma için sistemi null-safety yaptık
  stt.SpeechToText? _speechToText;
  bool _isListening = false;
  bool _isSpeechInitialized = false; // Sistem hazır mı kontrolü

  String _mainTranslation = "";
  String _wordType = "";
  String _imageUrl = "";
  String _searchedEnglishWord = "";

  List<WordMeaningGroup> _groupedMeanings = [];

  bool _isLoading = false;
  bool _isEnToTr = true;

  final List<TranslationCacheItem> _cachePool = [];
  final int _maxCacheSize = 50;

  final LinearGradient primaryGradient = LinearGradient(
    colors: [Colors.teal.shade700, Colors.tealAccent.shade700],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final String _proxyUrl = "https://ceviri-api.vercel.app/api/proxy";

  @override
  void initState() {
    super.initState();
    // 🚀 ADIM 9.8: initState içindeki ses hazırlama (initialize) satırını sildik!
  }

  @override
  void dispose() {
    if (_isListening) {
      _speechToText?.stop();
    }
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _openCameraScanner() async {
    final scannedWord = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraScannerScreen()),
    );

    if (scannedWord != null &&
        scannedWord is String &&
        scannedWord.isNotEmpty) {
      setState(() {
        _textController.text = scannedWord;
        _isEnToTr = true;
      });
      _translateAndFetchDictionary();
    }
  }

  // 🚀 ADIM 9.8: Dinleme fonksiyonu artık çok daha akıllı
  void _listen() async {
    // 1. Sistem daha önce kurulmadıysa şimdi kur
    if (!_isSpeechInitialized) {
      _speechToText = stt.SpeechToText();
      bool available = await _speechToText!.initialize(
        onStatus: (val) => debugPrint('Mikrofon Durumu: $val'),
        onError: (val) => debugPrint('Mikrofon Hatası: $val'),
      );
      if (available) {
        setState(() => _isSpeechInitialized = true);
      } else {
        debugPrint("Ses tanıma başlatılamadı.");
        return;
      }
    }

    // 2. Dinlemeyi başlat veya durdur
    if (!_isListening) {
      setState(() => _isListening = true);
      _speechToText!.listen(
        localeId: _isEnToTr ? 'en_US' : 'tr_TR',
        onResult: (val) {
          setState(() {
            _textController.text = val.recognizedWords;
          });
        },
      );
    } else {
      setState(() => _isListening = false);
      _speechToText!.stop();
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

  String _getShortPartSpeech(String trType) {
    switch (trType.toLowerCase()) {
      case 'i̇sim':
      case 'isim':
        return 'noun';
      case 'sıfat':
        return 'adj.';
      case 'zarf':
        return 'adv.';
      case 'fiil':
        return 'verb';
      case 'zamir':
        return 'pron.';
      case 'edat':
        return 'prep.';
      case 'bağlaç':
        return 'conj.';
      default:
        return trType.toLowerCase();
    }
  }

  Future<String> _translateWithDeepL(
    String text, {
    String? sourceLang,
    String? targetLang,
  }) async {
    final url = Uri.parse('$_proxyUrl?service=deepl');
    final sLang = sourceLang ?? (_isEnToTr ? 'EN' : 'TR');
    final tLang = targetLang ?? (_isEnToTr ? 'TR' : 'EN-US');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': [text],
          'source_lang': sLang,
          'target_lang': tLang,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['translations'] != null && data['translations'].isNotEmpty) {
          return data['translations'][0]['text'];
        }
        return "Çeviri Bulunamadı";
      } else {
        return "Çeviri Hatası";
      }
    } catch (e) {
      return "Bağlantı Hatası";
    }
  }

  Future<Map<String, List<String>>> _fetchGoogleDictionaryMeanings(
    String word,
  ) async {
    Map<String, List<String>> dictionaryResults = {};
    try {
      final url = Uri.parse(
        '$_proxyUrl?service=google&sl=en&tl=tr&word=${Uri.encodeComponent(word)}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data.length > 1 && data[1] != null) {
          for (var item in data[1]) {
            String type = item[0].toString();
            List<String> meanings = (item[1] as List)
                .map((e) => e.toString())
                .toList();
            dictionaryResults[_translateWordType(type)] = meanings;
          }
        }
      }
    } catch (e) {
      debugPrint("Google Dictionary Hatası: $e");
    }
    return dictionaryResults;
  }

  Future<void> _translateAndFetchDictionary() async {
    final textToTranslate = _textController.text.trim().toLowerCase();
    if (textToTranslate.isEmpty) return;

    if (_isListening) {
      setState(() => _isListening = false);
      _speechToText?.stop();
    }

    final cachedIndex = _cachePool.indexWhere(
      (item) =>
          item.originalText == textToTranslate && item.isEnToTr == _isEnToTr,
    );

    if (cachedIndex != -1) {
      final cachedData = _cachePool[cachedIndex];
      setState(() {
        _mainTranslation = cachedData.mainTranslation;
        _imageUrl = cachedData.imageUrl;
        _searchedEnglishWord = cachedData.searchedEnglishWord;
        _groupedMeanings = List.from(cachedData.groupedMeanings);
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _mainTranslation = "";
      _wordType = "";
      _groupedMeanings = [];
      _imageUrl = "";
      _searchedEnglishWord = "";
    });

    try {
      String deepLResult = await _translateWithDeepL(textToTranslate);

      if (!_isEnToTr &&
          deepLResult.toLowerCase() == textToTranslate &&
          !textToTranslate.contains(' ')) {
        String contextResult = await _translateWithDeepL(
          "bir $textToTranslate",
        );
        contextResult = contextResult.toLowerCase();

        if (contextResult.startsWith("a "))
          deepLResult = contextResult.substring(2).trim();
        else if (contextResult.startsWith("an "))
          deepLResult = contextResult.substring(3).trim();
        else if (contextResult.startsWith("the "))
          deepLResult = contextResult.substring(4).trim();
        else
          deepLResult = contextResult;
      }

      if (deepLResult.isNotEmpty && !deepLResult.contains("Hata")) {
        _mainTranslation =
            deepLResult[0].toUpperCase() + deepLResult.substring(1);
      } else {
        _mainTranslation = deepLResult;
      }

      String englishWordToSearch = _isEnToTr
          ? textToTranslate
          : deepLResult.toLowerCase();
      _searchedEnglishWord = englishWordToSearch;

      if (!englishWordToSearch.contains(' ')) {
        await _fetchDictionaryData(englishWordToSearch, textToTranslate);

        if (_wordType == 'İsim' ||
            _wordType == 'Sıfat' ||
            _wordType == 'Fiil' ||
            _wordType.isEmpty) {
          await _fetchImage(englishWordToSearch);
        }
      }

      if (_mainTranslation.isNotEmpty && !_mainTranslation.contains("Hata")) {
        if (_cachePool.length >= _maxCacheSize) {
          _cachePool.removeAt(0);
        }
        _cachePool.add(
          TranslationCacheItem(
            originalText: textToTranslate,
            isEnToTr: _isEnToTr,
            mainTranslation: _mainTranslation,
            imageUrl: _imageUrl,
            searchedEnglishWord: _searchedEnglishWord,
            groupedMeanings: List.from(_groupedMeanings),
          ),
        );
      }
    } catch (e) {
      setState(() => _mainTranslation = "Sistemsel bir hata oluştu.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDictionaryData(
    String englishWord,
    String originalWord,
  ) async {
    try {
      if (_isEnToTr) {
        Map<String, List<String>> googleMeanings =
            await _fetchGoogleDictionaryMeanings(englishWord);
        final url = Uri.parse(
          'https://api.dictionaryapi.dev/api/v2/entries/en/$englishWord',
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

                List<String> shortTrMeanings =
                    googleMeanings[partOfSpeech] ?? [];

                List<Map<String, String>> examples = [];
                int defCount = 0;
                for (var def in definitions) {
                  if (defCount >= 3) break;
                  final engEx = def['example']?.toString() ?? "";
                  if (engEx.isNotEmpty) {
                    final trEx = await _translateWithDeepL(
                      engEx,
                      sourceLang: 'EN',
                      targetLang: 'TR',
                    );
                    if (!trEx.contains("Hata"))
                      examples.add({'eng': engEx, 'tr': trEx});
                    defCount++;
                  }
                }

                if (mounted &&
                    (shortTrMeanings.isNotEmpty || examples.isNotEmpty)) {
                  setState(() {
                    int existingIndex = _groupedMeanings.indexWhere(
                      (g) => g.partOfSpeech == partOfSpeech,
                    );
                    if (existingIndex != -1) {
                      _groupedMeanings[existingIndex].contextualExamples.addAll(
                        examples,
                      );
                    } else {
                      _groupedMeanings.add(
                        WordMeaningGroup(
                          partOfSpeech: partOfSpeech,
                          shortMeanings: shortTrMeanings,
                          contextualExamples: examples,
                        ),
                      );
                    }
                  });
                }
              }
            }
          }
        }

        if (_groupedMeanings.isEmpty && googleMeanings.isNotEmpty && mounted) {
          setState(() {
            googleMeanings.forEach((type, meanings) {
              _groupedMeanings.add(
                WordMeaningGroup(
                  partOfSpeech: type,
                  shortMeanings: meanings,
                  contextualExamples: [],
                ),
              );
            });
          });
        }
      } else {
        final url = Uri.parse(
          '$_proxyUrl?service=google&sl=tr&tl=en&word=${Uri.encodeComponent(originalWord)}',
        );
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data != null && data.length > 1 && data[1] != null) {
            for (var item in data[1]) {
              String type = item[0].toString();
              List<Map<String, List<String>>> reverseList = [];

              if (item.length > 2 && item[2] != null) {
                for (var revItem in item[2]) {
                  String engWord = revItem[0].toString();
                  List<String> trWords = (revItem[1] as List)
                      .map((e) => e.toString())
                      .toList();
                  reverseList.add({engWord: trWords});
                }
              }

              if (reverseList.isNotEmpty && mounted) {
                setState(() {
                  _groupedMeanings.add(
                    WordMeaningGroup(
                      partOfSpeech: _translateWordType(type),
                      shortMeanings: [],
                      contextualExamples: [],
                      reverseMeanings: reverseList,
                    ),
                  );
                });
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
    try {
      final url = Uri.parse(
        '$_proxyUrl?service=pexels&word=${Uri.encodeComponent(word)}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['photos'] != null && data['photos'].isNotEmpty) {
          if (mounted)
            setState(() => _imageUrl = data['photos'][0]['src']['medium']);
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

  Widget _buildHighlightedText(String text, String highlightWord) {
    if (highlightWord.isEmpty)
      return Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontStyle: FontStyle.italic,
          color: Colors.black87,
        ),
      );

    final RegExp regex = RegExp(
      RegExp.escape(highlightWord),
      caseSensitive: false,
    );
    final Iterable<RegExpMatch> matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontStyle: FontStyle.italic,
          color: Colors.black87,
        ),
      );
    }

    List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (var match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: const TextStyle(color: Colors.black87),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            backgroundColor: Colors.grey.shade300,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: const TextStyle(color: Colors.black87),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
        children: spans,
      ),
    );
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
                _groupedMeanings = [];
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
              if (_isEnToTr)
                IconButton(
                  icon: const Icon(Icons.volume_up, color: Colors.teal),
                  onPressed: () => _speak(_textController.text, 'en-US'),
                ),
              if (!kIsWeb)
                IconButton(
                  icon: Icon(Icons.camera_alt, color: Colors.teal.shade700),
                  onPressed: _openCameraScanner,
                ),
              IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.red : Colors.teal.shade400,
                  size: _isListening ? 30 : 26,
                ),
                onPressed: _listen,
              ),
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () => setState(() {
                  _textController.clear();
                  _mainTranslation = "";
                  _imageUrl = "";
                  _groupedMeanings = [];
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
      crossAxisAlignment: CrossAxisAlignment.start,
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
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.teal,
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
                  Text(
                    _isEnToTr
                        ? _textController.text.trim().toLowerCase()
                        : _mainTranslation.toLowerCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                      fontSize: 22,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.teal),
                    onPressed: () => _speak(
                      _isEnToTr
                          ? _textController.text.trim()
                          : _mainTranslation,
                      'en-US',
                    ),
                  ),
                ],
              ),
              const Divider(),

              Text(
                _isEnToTr ? _mainTranslation : _textController.text.trim(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 15),

              if (_isEnToTr && _groupedMeanings.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _groupedMeanings.map((group) {
                    if (group.shortMeanings.isEmpty)
                      return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  "(${_getShortPartSpeech(group.partOfSpeech)}) ",
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                                fontSize: 16,
                              ),
                            ),
                            TextSpan(
                              text: group.shortMeanings.join(', '),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),

        if (!_isEnToTr && _groupedMeanings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 25.0, bottom: 5.0),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Colors.orange.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "\"${_textController.text.trim().toLowerCase()}\" kelimesinin kullanım yerine göre İngilizce karşılıkları:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (!_isEnToTr && _groupedMeanings.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blueGrey.shade100, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _groupedMeanings.map((group) {
                if (group.reverseMeanings.isEmpty)
                  return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.partOfSpeech.toLowerCase(),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ...group.reverseMeanings.map((rev) {
                        String engWord = rev.keys.first;
                        List<String> trMeanings = rev.values.first;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: Colors.blueAccent.shade400,
                                width: 3,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.only(left: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                engWord,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                trMeanings.join(', '),
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      if (group != _groupedMeanings.last)
                        const Divider(
                          height: 10,
                          thickness: 1,
                          color: Colors.black12,
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

        if (_isEnToTr &&
            _groupedMeanings.any((g) => g.contextualExamples.isNotEmpty))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blueGrey.shade200, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      color: Colors.blueGrey.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Örnekler: Bağlam içi kullanım",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                ..._groupedMeanings
                    .where((g) => g.contextualExamples.isNotEmpty)
                    .map((group) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 8.0,
                              top: 10.0,
                            ),
                            child: Text(
                              "[${_getShortPartSpeech(group.partOfSpeech)}]",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          ...group.contextualExamples.map(
                            (ex) => Padding(
                              padding: const EdgeInsets.only(bottom: 15.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHighlightedText(
                                    ex['eng'] ?? '',
                                    _searchedEnglishWord,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ex['tr'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (group != _groupedMeanings.last)
                            const Divider(
                              height: 10,
                              thickness: 1,
                              color: Colors.black12,
                            ),
                        ],
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
