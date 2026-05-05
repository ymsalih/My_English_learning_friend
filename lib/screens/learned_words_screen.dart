import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'tts_service.dart';

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
    colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)], // Indigo 600 to Cyan 500
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.refresh_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text("Kelime tekrar test havuzuna eklendi!"),
              ],
            ),
            backgroundColor: const Color(0xFF06B6D4), // Turkuaz bilgi mesajı
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
                Text("Kelime kalıcı olarak silindi."),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444), // Canlı kırmızı
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
      backgroundColor: const Color(
        0xFFF8FAFC,
      ), // Çok hafif buz mavisi/beyaz zemin
      appBar: AppBar(
        title: const Text(
          'Öğrendiklerim (Arşiv)',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: primaryGradient),
        ),
      ),
      body: user == null
          ? const Center(child: Text("Oturum açılmamış."))
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
                      color: Color(0xFF4F46E5), // İndigo yükleme ikonu
                    ),
                  );
                }

                final allDocs = snapshot.data?.docs ?? [];

                if (allDocs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
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
                            color: Color(0xFF4F46E5),
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
                );
              },
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
              backgroundColor: const Color(0xFF06B6D4), // Turkuaz
              foregroundColor: Colors.white,
              icon: Icons.settings_backup_restore_rounded,
              label: 'Havuza Al',
            ),
            SlidableAction(
              onPressed: (context) =>
                  _showDeleteDialog(word['eng'], word['docId']),
              backgroundColor: const Color(0xFFEF4444), // Kırmızı
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF4F46E5,
                ).withOpacity(0.06), // İndigo tonlu soft gölge
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
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
                      color: const Color(0xFFF59E0B).withOpacity(
                        0.15,
                      ), // Çok hafif pastel sarı/kehribar zemin
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.school_rounded,
                        color: Color(0xFFF59E0B), // Daha koyu ve mat ikon rengi
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
                            color: Color(
                              0xFF0F172A,
                            ), // Koyu Slate (Siyah-Lacivert arası)
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          word['tr'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(
                              0xFF4F46E5,
                            ), // İndigo (Göz yormaz, belirgindir)
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
                      color: const Color(0xFFEEF2FF), // Açık İndigo arkaplan
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _speak(word['eng']),
                        splashColor: const Color(0xFF4F46E5).withOpacity(0.2),
                        child: const Icon(
                          Icons.volume_up_rounded,
                          color: Color(0xFF4F46E5), // Canlı İndigo ikon
                          size: 26,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Havuza Geri Ekle",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF06B6D4), // Turkuaz
          ),
        ),
        content: Text(
          "'$engWord' kelimesini tekrar öğrenmek üzere test havuzuna geri almak istiyor musun?",
          style: const TextStyle(color: Color(0xFF475569), fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "İptal",
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _restoreToPool(docId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Kalıcı Olarak Sil",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFEF4444),
          ),
        ),
        content: Text(
          "'$engWord' kelimesini hesabından tamamen silmek istediğine emin misin? Bu işlem geri alınamaz.",
          style: const TextStyle(color: Color(0xFF475569), fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "İptal",
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteWord(docId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
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
          ShaderMask(
            shaderCallback: (bounds) => primaryGradient.createShader(bounds),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 100,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Henüz Öğrendiğin Kelime Yok',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Test ekranında "Öğrendim" dediğin\nkelimeler burada toplanacak.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
