import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
// 🚀 YENİ: Ses servisini içeri aktarıyoruz
import 'tts_service.dart';
import 'package:translator/translator.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // 🚀 GÜNCELLEME: Eski FlutterTts yerine merkezi servisimizi tanımlıyoruz
  final TtsService _ttsService = TtsService();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final ScrollController _scrollController = ScrollController();
  int _documentLimit = 20;
  bool _isFetchingMore = false;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isFetchingMore) {
        setState(() {
          _isFetchingMore = true;
          _documentLimit += 20;
        });

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isFetchingMore = false;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 🚀 GÜNCELLEME: Artık merkezi servisi kullanarak konuşuyoruz
  Future<void> _speak(String text) async {
    await _ttsService.speak(text);
  }

  Future<void> _deleteWord(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('words')
        .doc(docId)
        .delete();
  }

  void _showAddWordBottomSheet() {
    final engController = TextEditingController();
    final trController = TextEditingController();
    Timer? debounce;
    bool isTranslating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            
            void onEngTextChanged(String text) {
              if (debounce?.isActive ?? false) debounce!.cancel();
              debounce = Timer(const Duration(milliseconds: 1000), () async {
                if (text.trim().isNotEmpty) {
                  setModalState(() => isTranslating = true);
                  try {
                    final translator = GoogleTranslator();
                    final translation = await translator.translate(text.trim(), from: 'en', to: 'tr');
                    // Kullanıcı zaten manuel bir şey yazmadıysa doldur
                    if (trController.text.isEmpty || isTranslating) {
                       trController.text = translation.text;
                    }
                  } catch (e) {
                    // Hata olursa sessizce geç
                  }
                  if (mounted) {
                    setModalState(() => isTranslating = false);
                  }
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A), // Dark premium background
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border(top: BorderSide(color: Color(0xFF334155), width: 1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Yeni Kelime Ekle',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: engController,
                      onChanged: onEngTextChanged,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'İngilizce (Otomatik Çevrilir)',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        prefixIcon: const Icon(Icons.language, color: Colors.blueAccent),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        suffixIcon: isTranslating 
                          ? const Padding(
                              padding: EdgeInsets.all(12), 
                              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
                            ) 
                          : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: trController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Türkçe',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        prefixIcon: const Icon(Icons.translate, color: Colors.purpleAccent),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent]),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          if (engController.text.isNotEmpty && trController.text.isNotEmpty) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user!.uid)
                                .collection('words')
                                .add({
                                  'eng': engController.text.trim(),
                                  'tr': trController.text.trim(),
                                  'timestamp': FieldValue.serverTimestamp(),
                                  'isLearned': false,
                                  'lastReviewed': Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(0)),
                                });
                            if (mounted) Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text(
                          'Havuza Kaydet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Kelime Havuzum',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Yüksek performanslı arka plan
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Performanslı glow efektleri
          Positioned(
            top: -100, right: -50,
            child: Container(
              width: 300, height: 300,
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Kelime Ara...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.5)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user?.uid)
                        .collection('words')
                        .where('isLearned', isEqualTo: false) // 🚀 Server-Side Filtreleme (Client yorulmaz)
                        .orderBy('timestamp', descending: true)
                        .limit(_searchQuery.isNotEmpty ? 1000 : _documentLimit)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
                        return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                      }
                      
                      if (snapshot.hasError) {
                        debugPrint("Firestore Hatası: ${snapshot.error}");
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text(
                              "Optimizasyon için Firebase Index gerekiyor.\nLütfen Terminal'de (Debug Console) beliren linke tıklayıp index oluşturun.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }

                      final words = (snapshot.data?.docs ?? []).where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (_searchQuery.isEmpty) return true;
                        return data['eng'].toString().toLowerCase().contains(_searchQuery) ||
                               data['tr'].toString().toLowerCase().contains(_searchQuery);
                      }).toList();

                      if (words.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 80, color: Colors.white.withOpacity(0.2)),
                              const SizedBox(height: 16),
                              Text("Havuzun Boş!", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                        itemCount: words.length + (_isFetchingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == words.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(15),
                                child: CircularProgressIndicator(color: Colors.purpleAccent),
                              ),
                            );
                          }
                          
                          final doc = words[index];
                          final data = doc.data() as Map<String, dynamic>;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Slidable(
                              key: ValueKey(doc.id),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                children: [
                                  SlidableAction(
                                    onPressed: (context) => _deleteWord(doc.id),
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.redAccent,
                                    icon: Icons.delete_outline_rounded,
                                    label: 'Sil',
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.auto_awesome_motion_rounded, color: Colors.blueAccent, size: 22),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['eng'],
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white, letterSpacing: -0.3),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            data['tr'],
                                            style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.w600, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
                                        onPressed: () => _speak(data['eng']),
                                        splashRadius: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showAddWordBottomSheet,
          elevation: 0,
          backgroundColor: Colors.transparent,
          label: const Text(
            'Yeni Kelime',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
    );
  }
}
