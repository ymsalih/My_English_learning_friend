import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
// 🚀 YENİ: Ses servisini içeri aktarıyoruz
import 'tts_service.dart';
import 'package:translator/translator.dart';
import 'dart:async';
import '../services/subscription_service.dart';
import 'paywall_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../widgets/cached_stream_builder.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // 🚀 GÜNCELLEME: Eski FlutterTts yerine merkezi servisimizi tanımlıyoruz
  final TtsService _ttsService = TtsService();
  final SubscriptionService _subService = SubscriptionService();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  int _currentUsage = 0;
  int _currentLimit = 50;
  bool _isUnlimited = false;

  final ScrollController _scrollController = ScrollController();
  int _documentLimit = 20;
  bool _isFetchingMore = false;

  @override
  void initState() {
    super.initState();
    _loadLimits();
    // Plan veya kullanım değişince (ör. paket yükseltme) limitler canlı güncellenir.
    SubscriptionService.changes.addListener(_loadLimits);

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

  Future<void> _loadLimits() async {
    final usage = await _subService.getActionUsage('lifetimeWordsAdded');
    if (mounted) {
      setState(() {
        _currentUsage = usage['current'] ?? 0;
        _currentLimit = usage['limit'] ?? 50;
        _isUnlimited = _currentLimit >= 999999;
      });
    }
  }

  @override
  void dispose() {
    SubscriptionService.changes.removeListener(_loadLimits);
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

  void _showAddWordBottomSheet() async {
    if (!await _subService.canAddWord()) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const PaywallScreen()));
      }
      return;
    }

    if (!mounted) return;

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
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text('Yeni Kelime Ekle', style: AppText.heading(size: 21)),
                      const SizedBox(height: AppSpacing.xs),
                      Text('İngilizcesini yaz, Türkçesi otomatik gelsin.', style: AppText.caption),
                      const SizedBox(height: AppSpacing.xl),
                      TextField(
                        controller: engController,
                        onChanged: onEngTextChanged,
                        autofocus: true,
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'İngilizce',
                          prefixIcon: const Icon(Icons.language_rounded),
                          suffixIcon: isTranslating
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: trController,
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Türkçe',
                          prefixIcon: Icon(Icons.translate_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton.icon(
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
                            await _subService.incrementWordCount();
                            await _loadLimits();
                            if (mounted) Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Havuza Kaydet'),
                      ),
                    ],
                  ),
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
      appBar: AppBar(
        backgroundColor: AppColors.bgTop,
        title: const Text('Kelime Havuzum'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: InfoPill(
              icon: Icons.style_outlined,
              label: _isUnlimited ? "Sınırsız" : "$_currentUsage/$_currentLimit",
            ),
          ),
        ],
      ),
      body: AppBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.sm),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Kelime ara...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              // Dinleyici yalnızca sorgu değişince (arama açılıp kapanınca veya
              // sayfa büyüyünce) yeniden kurulur; her harfte değil.
              child: CachedStreamBuilder<QuerySnapshot>(
                queryKey: (user?.uid, _searchQuery.isNotEmpty ? 1000 : _documentLimit),
                create: () => FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .collection('words')
                    .where('isLearned', isEqualTo: false) // 🚀 Server-Side Filtreleme (Client yorulmaz)
                    .orderBy('timestamp', descending: true)
                    .limit(_searchQuery.isNotEmpty ? 1000 : _documentLimit)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    debugPrint("Firestore Hatası: ${snapshot.error}");
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          "Kelimeler yüklenemedi. Lütfen daha sonra tekrar deneyin.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
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
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.section),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const IconBadge(icon: Icons.style_rounded, size: 80),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              _searchQuery.isEmpty ? "Havuzun boş" : "Sonuç bulunamadı",
                              style: AppText.heading(size: 20),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _searchQuery.isEmpty
                                  ? "Öğrenmek istediğin kelimeleri ekleyerek başla."
                                  : "Farklı bir kelimeyle aramayı dene.",
                              textAlign: TextAlign.center,
                              style: AppText.body,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, 100),
                    itemCount: words.length + (_isFetchingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == words.length) {
                        return const Center(
                          child: Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator()),
                        );
                      }

                      final doc = words[index];
                      final data = doc.data() as Map<String, dynamic>;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Slidable(
                          key: ValueKey(doc.id),
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (context) => _deleteWord(doc.id),
                                backgroundColor: AppColors.dangerFill,
                                foregroundColor: Colors.white,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                icon: Icons.delete_outline_rounded,
                                label: 'Sil',
                              ),
                            ],
                          ),
                          child: AppCard(
                            radius: AppRadius.md,
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['eng'],
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        data['tr'],
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.volume_up_rounded, color: AppColors.primaryLight, size: 22),
                                  onPressed: () => _speak(data['eng']),
                                  tooltip: 'Dinle',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWordBottomSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni Kelime', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
