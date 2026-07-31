import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:camera/camera.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';
import 'camera_scanner_screen.dart';
// 🚀 YENİ: Ses servisini içeri aktarıyoruz
import 'tts_service.dart';
import '../services/subscription_service.dart';
import 'paywall_screen.dart';

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

  Map<String, dynamic> toJson() => {
        'partOfSpeech': partOfSpeech,
        'shortMeanings': shortMeanings,
        'contextualExamples': contextualExamples,
        'reverseMeanings': reverseMeanings,
      };

  factory WordMeaningGroup.fromJson(Map<String, dynamic> json) {
    return WordMeaningGroup(
      partOfSpeech: json['partOfSpeech'] ?? '',
      shortMeanings: List<String>.from(json['shortMeanings'] ?? []),
      contextualExamples: (json['contextualExamples'] as List?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],
      reverseMeanings: (json['reverseMeanings'] as List?)?.map((e) {
            Map<String, List<String>> map = {};
            (e as Map).forEach((k, v) {
              map[k.toString()] = List<String>.from(v);
            });
            return map;
          }).toList() ??
          [],
    );
  }
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

  Map<String, dynamic> toJson() => {
        'originalText': originalText,
        'isEnToTr': isEnToTr,
        'mainTranslation': mainTranslation,
        'imageUrl': imageUrl,
        'searchedEnglishWord': searchedEnglishWord,
        'groupedMeanings': groupedMeanings.map((g) => g.toJson()).toList(),
      };

  factory TranslationCacheItem.fromJson(Map<String, dynamic> json) {
    return TranslationCacheItem(
      originalText: json['originalText'] ?? '',
      isEnToTr: json['isEnToTr'] ?? true,
      mainTranslation: json['mainTranslation'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      searchedEnglishWord: json['searchedEnglishWord'] ?? '',
      groupedMeanings: (json['groupedMeanings'] as List?)
              ?.map((e) => WordMeaningGroup.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  // 🚀 GÜNCELLEME: Merkezi ses servisimizi tanımlıyoruz
  final TtsService _ttsService = TtsService();

  stt.SpeechToText? _speechToText;
  bool _isListening = false;
  bool _isSpeechInitialized = false;

  String _mainTranslation = "";
  String _wordType = "";
  String _imageUrl = "";
  String _searchedEnglishWord = "";
  List<WordMeaningGroup> _groupedMeanings = [];

  bool _isLoading = false;
  bool _isEnToTr = true;
  final SubscriptionService _subService = SubscriptionService();
  int _currentUsage = 0;
  int _currentLimit = 20;
  bool _isUnlimited = false;

  static final List<TranslationCacheItem> _cachePool = []; // 🚀 O(1) Global RAM Cache
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
    _speechToText = stt.SpeechToText();
    _loadLimits();
  }

  Future<void> _loadLimits() async {
    final usage = await _subService.getActionUsage('translateCount');
    if (mounted) {
      setState(() {
        _currentUsage = usage['current'] ?? 0;
        _currentLimit = usage['limit'] ?? 20;
        _isUnlimited = _currentLimit >= 999999;
      });
    }
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
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      bool canTranslate = await _subService.canTranslate();
      if (!canTranslate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Günlük çeviri limitiniz doldu. Sınırsız kullanım için paketinizi yükseltin.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
    }

    if (cameras.isEmpty) {
      try {
        cameras = await availableCameras();
      } catch (e) {
        debugPrint("Kameralar alınırken hata oluştu: $e");
      }
    }

    if (!mounted) return;
    final scannedWord = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraScannerScreen()),
    );
    if (scannedWord != null &&
        scannedWord is String &&
        scannedWord.isNotEmpty) {
      
      if (user != null) {
        await _subService.incrementTranslate();
      }

      setState(() {
        _textController.text = scannedWord;
        _isEnToTr = true;
      });
      _translateAndFetchDictionary();
    }
  }

  void _listen() async {
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

  // 🚀 GÜNCELLEME: Artık merkezi servisi kullanarak konuşuyoruz
  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await _ttsService.speak(text);
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
      } else if (response.statusCode == 429) {
        // RATE LIMIT (Çok Fazla İstek) Yakalandı
        return "Sistem yoğun. Lütfen 1 dakika bekleyin.";
      } else {
        return "Çeviri Hatası (${response.statusCode})";
      }
    } catch (e) {
      return "Bağlantı Hatası (Sunucu engeli veya internet sorunu)";
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

    if (!await _subService.canTranslate()) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const PaywallScreen()));
      }
      return;
    }
    await _subService.incrementTranslate();
    await _loadLimits();

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
      // 🚀 GLOBAL CACHE KONTROLÜ
      if (!textToTranslate.contains(' ')) {
        String cacheDocId = "${_isEnToTr ? 'en' : 'tr'}_$textToTranslate";
        final globalCacheDoc = await FirebaseFirestore.instance.collection('dictionary_cache').doc(cacheDocId).get();
        if (globalCacheDoc.exists) {
           final cacheData = globalCacheDoc.data()!;
           final cacheItem = TranslationCacheItem.fromJson(cacheData);
           
           setState(() {
             _mainTranslation = cacheItem.mainTranslation;
             _imageUrl = cacheItem.imageUrl;
             _searchedEnglishWord = cacheItem.searchedEnglishWord;
             _groupedMeanings = List.from(cacheItem.groupedMeanings);
             _isLoading = false;
           });
           
           if (_cachePool.length >= _maxCacheSize) _cachePool.removeAt(0);
           _cachePool.add(cacheItem);
           
           return;
        }
      }

      String deepLResult = await _translateWithDeepL(textToTranslate);
      if (!_isEnToTr &&
          deepLResult.toLowerCase() == textToTranslate &&
          !textToTranslate.contains(' ')) {
        String contextResult = await _translateWithDeepL(
          "bir $textToTranslate",
        );
        contextResult = contextResult.toLowerCase();

        if (contextResult.startsWith("a ")) {
          deepLResult = contextResult.substring(2).trim();
        } else if (contextResult.startsWith("an "))
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
        final cacheItem = TranslationCacheItem(
          originalText: textToTranslate,
          isEnToTr: _isEnToTr,
          mainTranslation: _mainTranslation,
          imageUrl: _imageUrl,
          searchedEnglishWord: _searchedEnglishWord,
          groupedMeanings: List.from(_groupedMeanings),
        );

        if (_cachePool.length >= _maxCacheSize) {
          _cachePool.removeAt(0);
        }
        _cachePool.add(cacheItem);

        // 🚀 GLOBAL CACHE'E KAYDET
        if (!textToTranslate.contains(' ')) {
           String cacheDocId = "${_isEnToTr ? 'en' : 'tr'}_$textToTranslate";
           await FirebaseFirestore.instance.collection('dictionary_cache').doc(cacheDocId).set(cacheItem.toJson());
        }
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
                    if (!trEx.contains("Hata")) {
                      examples.add({'eng': engEx, 'tr': trEx});
                    }
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
          if (mounted) {
            setState(() => _imageUrl = data['photos'][0]['src']['medium']);
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

    if (!await _subService.canAddWord()) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const PaywallScreen()));
      }
      return;
    }
    await _subService.incrementWordCount();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('words')
        .add({
          'eng': _isEnToTr ? _textController.text.trim() : _mainTranslation,
          'tr': _isEnToTr ? _mainTranslation : _textController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
          'isLearned': false,
          'lastReviewed': Timestamp.fromDate(
            DateTime.fromMillisecondsSinceEpoch(0),
          ),
        });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Havuza akıllıca eklendi! ✨',
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
    if (highlightWord.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontStyle: FontStyle.italic,
          color: Colors.white.withOpacity(0.85),
        ),
      );
    }
    final RegExp regex = RegExp(
      RegExp.escape(highlightWord),
      caseSensitive: false,
    );
    final Iterable<RegExpMatch> matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontStyle: FontStyle.italic,
          color: Colors.white.withOpacity(0.85),
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
            style: TextStyle(color: Colors.white.withOpacity(0.85)),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: const TextStyle(
            backgroundColor: Colors.blueAccent,
            color: Colors.white,
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
          style: TextStyle(color: Colors.white.withOpacity(0.85)),
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
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Akıllı Çeviri',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
              ),
              child: Text(
                _isUnlimited ? "Sınırsız" : "$_currentUsage/$_currentLimit",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Uzay Arka Plan (Glow Effects)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -100, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.blueAccent.withOpacity(0.15), Colors.transparent],
                  stops: const [0.1, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50, right: -50,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.purpleAccent.withOpacity(0.15), Colors.transparent],
                  stops: const [0.1, 1.0],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildLanguageSelector(),
                  const SizedBox(height: 20),
                  _buildInput(),
                  const SizedBox(height: 20),
                  _buildActionButton(),
                  const SizedBox(height: 30),
                  _buildResult(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            _isEnToTr ? '🇬🇧 EN' : '🇹🇷 TR',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
          ),
          IconButton(
            icon: const Icon(
              Icons.swap_horizontal_circle,
              size: 35,
              color: Colors.blueAccent,
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isListening ? Colors.redAccent.withOpacity(0.8) : Colors.white.withOpacity(0.08), 
          width: 1.5
        ),
        boxShadow: [
          BoxShadow(
            color: _isListening ? Colors.redAccent.withOpacity(0.15) : Colors.black.withOpacity(0.2),
            blurRadius: _isListening ? 20 : 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            focusNode: _focusNode,
            controller: _textController,
            maxLines: 8,
            minLines: 2,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 18, color: Colors.white),
            cursorColor: Colors.blueAccent,
            inputFormatters: _isEnToTr
                ? [FilteringTextInputFormatter.deny(RegExp(r'[çÇğĞıİöÖşŞüÜ]'))]
                : [],
            decoration: InputDecoration(
              hintText: _isListening
                  ? (_isEnToTr ? 'Listening...' : 'Dinleniyor...')
                  : (_isEnToTr
                        ? 'Type or speak an English word/sentence...'
                        : 'Türkçe metin yazın veya konuşun...'),
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          // ARAÇ ÇUBUĞU (TOOLBAR)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isEnToTr)
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.blueAccent),
                    tooltip: "Dinle",
                    onPressed: () => _speak(_textController.text),
                  ),
                if (!kIsWeb)
                  IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.purpleAccent),
                    tooltip: "Kamera ile Okut",
                    onPressed: _openCameraScanner,
                  ),
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.redAccent : Colors.white70,
                    size: _isListening ? 30 : 26,
                  ),
                  tooltip: "Konuşarak Yaz",
                  onPressed: _listen,
                ),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54),
                  tooltip: "Temizle",
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
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _translateAndFetchDictionary,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
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
                  letterSpacing: 1,
                ),
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
            color: const Color(0xFF1E293B).withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
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
                    child: CachedNetworkImage(
                      imageUrl: _imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      placeholder: (context, url) => Container(
                        height: 200,
                        width: double.infinity,
                        color: Colors.white.withOpacity(0.05),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.purpleAccent),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 200,
                        width: double.infinity,
                        color: Colors.white.withOpacity(0.05),
                        child: const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white54,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _isEnToTr
                          ? _textController.text.trim().toLowerCase()
                          : _mainTranslation.toLowerCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.volume_up, color: Colors.blueAccent),
                      onPressed: () => _speak(
                        _isEnToTr ? _textController.text.trim() : _mainTranslation,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 30),

              Text(
                _isEnToTr ? _mainTranslation : _textController.text.trim(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 15),

              if (_isEnToTr && _groupedMeanings.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _groupedMeanings.map((group) {
                    if (group.shortMeanings.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "(${_getShortPartSpeech(group.partOfSpeech)}) ",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontStyle: FontStyle.italic,
                                fontSize: 16,
                              ),
                            ),
                            TextSpan(
                              text: group.shortMeanings.join(', '),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
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
            padding: const EdgeInsets.only(top: 25.0, bottom: 10.0),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: Colors.orangeAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "\"${_textController.text.trim().toLowerCase()}\" kelimesinin kullanım yerine göre İngilizce karşılıkları:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.8),
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
              color: const Color(0xFF1E293B).withOpacity(0.7),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _groupedMeanings.map((group) {
                if (group.reverseMeanings.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.partOfSpeech.toLowerCase(),
                        style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ...group.reverseMeanings.map((rev) {
                        String engWord = rev.keys.first;
                        List<String> trMeanings = rev.values.first;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: const BoxDecoration(
                            border: Border(left: BorderSide(color: Colors.blueAccent, width: 3)),
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
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                trMeanings.join(', '),
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (group != _groupedMeanings.last)
                        const Divider(height: 10, thickness: 1, color: Colors.white12),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

        if (_isEnToTr && _groupedMeanings.any((g) => g.contextualExamples.isNotEmpty))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.5),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.format_quote_rounded, color: Colors.blueAccent, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      "Örnekler: Bağlam içi kullanım",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.9),
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
                            padding: const EdgeInsets.only(bottom: 8.0, top: 10.0),
                            child: Text(
                              "[${_getShortPartSpeech(group.partOfSpeech)}]",
                              style: const TextStyle(color: Colors.purpleAccent, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),

                          ...group.contextualExamples.map(
                            (ex) => Padding(
                              padding: const EdgeInsets.only(bottom: 15.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHighlightedText(ex['eng'] ?? '', _searchedEnglishWord),
                                  const SizedBox(height: 4),
                                  Text(
                                    ex['tr'] ?? '',
                                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (group != _groupedMeanings.last)
                            const Divider(height: 10, thickness: 1, color: Colors.white12),
                        ],
                      );
                    }),
              ],
            ),
          ),

        const SizedBox(height: 25),

        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: OutlinedButton.icon(
            onPressed: _saveToPool,
            icon: const Icon(Icons.add_task),
            label: const Text(
              'Bu Kelimeyi Havuzuma Ekle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 55),
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.purpleAccent.withOpacity(0.6), width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              backgroundColor: const Color(0xFF1E293B).withOpacity(0.8),
            ),
          ),
        ),
      ],
    );
  }
}
