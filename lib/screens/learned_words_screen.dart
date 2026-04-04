import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class LearnedWordsScreen extends StatefulWidget {
  const LearnedWordsScreen({super.key});

  @override
  State<LearnedWordsScreen> createState() => _LearnedWordsScreenState();
}

class _LearnedWordsScreenState extends State<LearnedWordsScreen> {
  List<Map<String, dynamic>> _learnedWords = [];
  bool _isLoading = true;
  final FlutterTts flutterTts = FlutterTts();

  // 🔮 ANA TEMA GRADYANI (Pembe/Yakut)
  final LinearGradient primaryGradient = LinearGradient(
    colors: [Colors.pink.shade600, Colors.pinkAccent.shade400],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _fetchLearnedWords();
  }

  Future<void> _speak(String text) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.55);
    await flutterTts.speak(text);
  }

  Future<void> _fetchLearnedWords() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('words')
          .where('isLearned', isEqualTo: true)
          .get();

      final wordsList = snapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();

      setState(() {
        _learnedWords = wordsList;
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreToPool(String docId, int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('words')
          .doc(docId)
          .update({'isLearned': false});

      setState(() {
        _learnedWords.removeAt(index);
      });

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
            backgroundColor: Colors.blueAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteWord(String docId, int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('words')
          .doc(docId)
          .delete();

      setState(() {
        _learnedWords.removeAt(index);
      });

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
            backgroundColor: Colors.redAccent,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Öğrendiklerim (Arşiv)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: primaryGradient),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: Colors.pink.shade600),
              )
            : _learnedWords.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _learnedWords.length,
                itemBuilder: (context, index) {
                  final word = _learnedWords[index];
                  return _buildLearnedWordCard(word, index);
                },
              ),
      ),
    );
  }

  // --- 🛠️ YAN YANA (SIDE-BY-SIDE) KART TASARIMI ---
  Widget _buildLearnedWordCard(Map<String, dynamic> word, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Slidable(
        key: ValueKey(word['docId']),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.45,
          children: [
            SlidableAction(
              onPressed: (context) =>
                  _showRestoreDialog(word['eng'], word['docId'], index),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              icon: Icons.settings_backup_restore_rounded,
              label: 'Havuza Al',
            ),
            SlidableAction(
              onPressed: (context) =>
                  _showDeleteDialog(word['eng'], word['docId'], index),
              backgroundColor: const Color(
                0xFFFF1744,
              ), // YENİ: Çok daha canlı, neon bir kırmızı
              foregroundColor: Colors.white,
              icon: Icons.delete_outline_rounded,
              label: 'Sil',
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
          ],
        ),

        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              // 1. İKON (Mezuniyet Şapkası)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 15),

              // 2. YAN YANA KELİMELER VE AYIRICI ÇİZGİ
              Expanded(
                child: Row(
                  children: [
                    // İngilizce Kelime
                    Expanded(
                      child: Text(
                        word['eng'],
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(
                            0xFF2C3E50,
                          ), // YENİ: Çok şık, koyu lacivert-gri (Asil bir görünüm)
                        ),
                      ),
                    ),

                    // Şık Dikey Ayırıcı Çizgi
                    Container(
                      height: 25,
                      width: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade100,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),

                    // Türkçe Anlamı
                    Expanded(
                      child: Text(
                        word['tr'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors
                              .pink
                              .shade600, // YENİ: AppBar ile birebir uyumlu canlı pembe
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. DİNLE BUTONU
              IconButton(
                icon: Icon(
                  Icons.volume_up_rounded,
                  color: Colors.pink.shade400,
                  size: 26,
                ),
                onPressed: () => _speak(word['eng']),
                tooltip: "Dinle",
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(), // Butonun gereksiz boşluk kaplamasını engeller
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- ONAY DİYALOGLARI ---
  void _showRestoreDialog(String engWord, String docId, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Havuza Geri Ekle",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.pink.shade600,
          ),
        ),
        content: Text(
          "'$engWord' kelimesini tekrar öğrenmek üzere test havuzuna geri almak istiyor musun?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _restoreToPool(docId, index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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

  void _showDeleteDialog(String engWord, String docId, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Kalıcı Olarak Sil",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        ),
        content: Text(
          "'$engWord' kelimesini hesabından tamamen silmek istediğine emin misin? Bu işlem geri alınamaz.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteWord(docId, index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(
                0xFFFF1744,
              ), // Diyalogdaki butonu da neon kırmızı yaptık
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
          Text(
            'Henüz Öğrendiğin Kelime Yok',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.pink.shade700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Test ekranında "Öğrendim" dediğin\nkelimeler burada toplanacak.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
