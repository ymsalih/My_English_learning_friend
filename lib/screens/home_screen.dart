import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final FlutterTts _flutterTts = FlutterTts();

  // 🌊 KELİME HAVUZUM ÖZEL TEMASI (Ana menüdeki mavi butona uyumlu)
  final LinearGradient primaryGradient = LinearGradient(
    colors: [Colors.blue.shade800, Colors.lightBlue.shade400],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _deleteWord(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('words')
        .doc(docId)
        .delete();
  }

  // EKRANIN ALTINDAN AÇILAN KELİME EKLEME MENÜSÜ
  void _showAddWordBottomSheet() {
    final engController = TextEditingController();
    final trController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),

                // Mavi Geçişli Başlık
                ShaderMask(
                  shaderCallback: (bounds) =>
                      primaryGradient.createShader(bounds),
                  child: const Text(
                    'Yeni Kelime Ekle',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: engController,
                  decoration: InputDecoration(
                    labelText: 'İngilizce Kelime',
                    prefixIcon: Icon(
                      Icons.language,
                      color: Colors.blue.shade600,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: Colors.blue.shade700,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: trController,
                  decoration: InputDecoration(
                    labelText: 'Türkçe Anlamı',
                    prefixIcon: Icon(
                      Icons.translate,
                      color: Colors.blue.shade600,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: Colors.blue.shade700,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // MAVİ GRADIENT BUTON
                Container(
                  decoration: BoxDecoration(
                    gradient: primaryGradient,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade300.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (engController.text.isNotEmpty &&
                          trController.text.isNotEmpty) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user!.uid)
                            .collection('words')
                            .add({
                              'eng': engController.text.trim(),
                              'tr': trController.text.trim(),
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Havuza Kaydet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kelime Havuzum',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        // 🌊 APPBAR İÇİN MAVİ GEÇİŞ
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: primaryGradient),
        ),
      ),
      // 🌊 ARKA PLAN: Çok açık buz mavisi
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .collection('words')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: Colors.blue.shade700),
              );
            }

            final words = snapshot.data?.docs ?? [];

            // HAVUZ BOŞSA
            if (words.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          primaryGradient.createShader(bounds),
                      child: const Icon(
                        Icons.auto_awesome_mosaic_rounded,
                        size: 100,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Havuzun şu an boş.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Hemen sağ alttaki butondan\nilk kelimeni ekleyerek başla!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
              );
            }

            // HAVUZDA KELİMELER VARSA
            return ListView.builder(
              padding: const EdgeInsets.only(
                top: 15,
                bottom: 90,
                left: 15,
                right: 15,
              ),
              itemCount: words.length,
              itemBuilder: (context, index) {
                final doc = words[index];
                final data = doc.data() as Map<String, dynamic>;
                final eng = data['eng'] ?? '';
                final tr = data['tr'] ?? '';

                return Dismissible(
                  key: Key(doc.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.redAccent, Colors.red],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.delete_sweep,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                  onDismissed: (direction) => _deleteWord(doc.id),
                  child: Card(
                    elevation: 4,
                    shadowColor: Colors.blue.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      // 🌊 İKON İÇİN MAVİ GEÇİŞ
                      leading: ShaderMask(
                        shaderCallback: (bounds) =>
                            primaryGradient.createShader(bounds),
                        child: const Icon(
                          Icons.bolt_rounded,
                          size: 35,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        eng,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        tr,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.volume_up_rounded,
                          color: Colors.blue.shade600,
                          size: 30,
                        ),
                        onPressed: () => _speak(eng),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      // 🌊 YÜZEN BUTON (Mavi Gradient FAB)
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: primaryGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade400.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showAddWordBottomSheet,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(
            Icons.add_circle_outline,
            color: Colors.white,
            size: 26,
          ),
          label: const Text(
            'Yeni Ekle',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
