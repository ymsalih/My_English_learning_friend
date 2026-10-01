import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'tts_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

class LearnedWordsScreen extends StatefulWidget {
  const LearnedWordsScreen({super.key});

  @override
  State<LearnedWordsScreen> createState() => _LearnedWordsScreenState();
}

class _LearnedWordsScreenState extends State<LearnedWordsScreen> {
  // 🚀 PERFORMANS OPTİMİZASYONU: Gerçek zamanlı akış ve dinamik limit (Pagination)
  final ScrollController _scrollController = ScrollController();
  int _documentLimit = 20;
  bool _isFetchingMore = false;

  final TtsService _ttsService = TtsService();

  // 💎 CANLI VE FERAH TEMA: Royal İndigo'dan Turkuaz'a Geçiş
  final LinearGradient primaryGradient = const LinearGradient(
    colors: [AppColors.secondary, AppColors.primary], // Indigo to Purple
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();

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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await _ttsService.speak(text);
  }

  Future<void> _restoreToPool(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('words')
          .doc(docId)
          .update({'isLearned': false});

      // 🚀 O(1) Optimizasyonu: Öğrenilen sayısını 1 azalt
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'stats.totalLearned': FieldValue.increment(-1),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.refresh_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text("Kelime tekrar test havuzuna eklendi!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            backgroundColor: AppColors.primary, // Indigo/Blue
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteWord(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('words')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.delete_sweep_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text("Kelime kalıcı olarak silindi.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            backgroundColor: AppColors.dangerFill, // Canlı kırmızı
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Öğrendiklerim'
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Uzay Arka Plan (Glow Effects)
          const Positioned.fill(child: AppBackground(child: SizedBox.expand())),
          
          user == null
              ? const Center(child: Text("Oturum açılmamış.", style: TextStyle(color: Colors.white)))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('words')
                      .where('isLearned', isEqualTo: true)
                      .limit(_documentLimit)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        snapshot.data == null) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryLight,
                        ),
                      );
                    }

                    final allDocs = snapshot.data?.docs ?? [];

                    if (allDocs.isEmpty) {
                      return _buildEmptyState();
                    }

                    return SafeArea(
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(
                          top: 15,
                          bottom: 30,
                          left: 16,
                          right: 16,
                        ),
                        itemCount: allDocs.length + (_isFetchingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == allDocs.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(15.0),
                                child: CircularProgressIndicator(
                                  color: AppColors.secondary,
                                  strokeWidth: 3,
                                ),
                              ),
                            );
                          }

                          final doc = allDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          data['docId'] = doc.id;

                          return _buildLearnedWordCard(data);
                        },
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  // --- 🛠️ YENİ CANLI VE FERAH KART TASARIMI ---
  Widget _buildLearnedWordCard(Map<String, dynamic> word) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Slidable(
        key: ValueKey(word['docId']),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.45,
          children: [
            SlidableAction(
              onPressed: (context) =>
                  _showRestoreDialog(word['eng'], word['docId']),
              backgroundColor: AppColors.primary.withOpacity(0.9), // Blue
              foregroundColor: Colors.white,
              icon: Icons.settings_backup_restore_rounded,
              label: 'Havuza Al',
            ),
            SlidableAction(
              onPressed: (context) =>
                  _showDeleteDialog(word['eng'], word['docId']),
              backgroundColor: AppColors.dangerFill.withOpacity(0.9), // Kırmızı
              foregroundColor: Colors.white,
              icon: Icons.delete_outline_rounded,
              label: 'Sil',
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.surface, width: 1.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // 🌟 YENİ: Softlaştırılmış Başarı Rozeti (Göz yormayan pastel zemin)
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.school_rounded,
                        color: AppColors.gold,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),

                  // 🌟 Yüksek Okunabilirlikli, Göz Yormayan Metinler
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word['eng'],
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          word['tr'],
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryLight, 
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 🌟 Canlı Dinleme Butonu
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _speak(word['eng']),
                        splashColor: AppColors.secondary.withOpacity(0.2),
                        child: const Icon(
                          Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- ONAY DİYALOGLARI ---
  void _showRestoreDialog(String engWord, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5)
        ),
        title: const Text(
          "Havuza Geri Ekle",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.secondary, 
          ),
        ),
        content: Text(
          "'$engWord' kelimesini tekrar öğrenmek üzere test havuzuna geri almak istiyor musun?",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "İptal",
              style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _restoreToPool(docId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Geri Ekle",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String engWord, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5)
        ),
        title: const Text(
          "Kalıcı Olarak Sil",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.danger,
          ),
        ),
        content: Text(
          "'$engWord' kelimesini hesabından tamamen silmek istediğine emin misin? Bu işlem geri alınamaz.",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "İptal",
              style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteWord(docId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerFill,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Sil",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 80,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'Henüz Öğrendiğin Kelime Yok',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Test ekranında "Öğrendim" dediğin\nkelimeler burada toplanacak.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
