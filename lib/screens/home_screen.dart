import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:ui'; // Modern efektler için gerekli

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final FlutterTts _flutterTts = FlutterTts();

  final LinearGradient primaryGradient = LinearGradient(
    colors: [Colors.blue.shade900, Colors.blue.shade400],
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

  void _showAddWordBottomSheet() {
    final engController = TextEditingController();
    final trController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          // Arka planı bulanıklaştıran premium efekt
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Padding(
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
                    ),
                  ),
                  const SizedBox(height: 25),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: primaryGradient,
                      borderRadius: BorderRadius.circular(15),
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
                        padding: const EdgeInsets.symmetric(vertical: 15),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Kelime Havuzum',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          // AppBar altına hafif blur
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: primaryGradient.withOpacity(0.8),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // --- KATMAN 1: ANA ARKA PLAN ---
          Container(color: const Color(0xFFF8FAFF)),

          // --- KATMAN 2: AURA IŞIKLARI ---
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade200.withOpacity(0.3),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.lightBlue.shade100.withOpacity(0.4),
              ),
            ),
          ),

          // --- KATMAN 3: SOYUT HATLAR (MODERN DOKUNUŞ) ---
          CustomPaint(
            size: Size(
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height,
            ),
            painter: BackgroundPainter(),
          ),

          // --- KATMAN 4: İÇERİK ---
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('words')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final words = snapshot.data?.docs ?? [];

                if (words.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 80,
                          color: Colors.blue.shade200,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Henüz kelime yok...',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    final doc = words[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withOpacity(0.85), // Cam efekti
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade900.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(15),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.bolt,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              data['eng'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 19,
                              ),
                            ),
                            subtitle: Text(
                              data['tr'],
                              style: const TextStyle(fontSize: 16),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.volume_up_rounded,
                                color: Colors.blue,
                              ),
                              onPressed: () => _speak(data['eng']),
                            ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWordBottomSheet,
        label: const Text(
          'Yeni Kelime',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: Colors.blue.shade800,
      ),
    );
  }
}

// ARKA PLANA SOYUT ÇİZGİLER ÇİZEN ÖZEL SINIF
class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.8,
      size.width * 0.5,
      size.height * 0.6,
    );
    path.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.4,
      size.width,
      size.height * 0.5,
    );

    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.2), 50, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
