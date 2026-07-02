import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// For BackdropFilter if needed

class ProgressReportScreen extends StatefulWidget {
  const ProgressReportScreen({super.key});

  @override
  State<ProgressReportScreen> createState() => _ProgressReportScreenState();
}

class _ProgressReportScreenState extends State<ProgressReportScreen> {
  // Sıralama Ayarları
  String _sortBy = 'timestamp';
  bool _descending = true;

  // --- KRİTİK FONKSİYON: TESTİ VE VERİLERİNİ SİL (stats. alanı nokta ile güncellenir) ---
  Future<void> _deleteTest(
    String uid,
    String testId,
    Map<String, dynamic> testData,
  ) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Test geçmişinden ilgili dokümanı sil
    DocumentReference testRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('test_history')
        .doc(testId);
    batch.delete(testRef);

    // 2. stats Map içindeki verileri GÜVENLİ yolla güncelle
    DocumentReference userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid);
    batch.update(userRef, {
      'stats.totalCorrect': FieldValue.increment(-(testData['correct'] ?? 0)),
      'stats.totalWrong': FieldValue.increment(-(testData['wrong'] ?? 0)),
      'stats.totalTests': FieldValue.increment(-1),
      'stats.totalMastered': FieldValue.increment(-(testData['mastered'] ?? 0)),
    });

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Test silindi, istatistikleriniz güncellendi."),
            backgroundColor: Colors.purpleAccent.withOpacity(0.9), // Temaya Uygun SnackBar
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        );
      }
    } catch (e) {
      debugPrint("Silme işlemi başarısız: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark Space Background
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _buildBackgroundDecor(),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- APP BAR ---
              SliverAppBar(
                expandedHeight: 120,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                flexibleSpace: const FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    "Gelişim Raporu",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                leading: _buildBackButton(),
              ),

              // --- ÜST KELİME KARTLARI ---
              SliverToBoxAdapter(child: _buildWordStats(user?.uid ?? "")),

              // --- BAŞLIK VE FİLTRELEME ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(25, 30, 25, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Test Yolculuğun",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      _buildFilterMenu(),
                    ],
                  ),
                ),
              ),

              // --- TEST GEÇMİŞİ LİSTESİ ---
              _buildTestHistoryList(user?.uid ?? ""),
            ],
          ),
        ],
      ),
    );
  }

  // --- FİLTRELEME MENÜSÜ ---
  Widget _buildFilterMenu() {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Icon(Icons.tune_rounded, color: Colors.purpleAccent, size: 20),
      ),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (val) {
        setState(() {
          if (val == 'new') {
            _sortBy = 'timestamp';
            _descending = true;
          } else if (val == 'old') {
            _sortBy = 'timestamp';
            _descending = false;
          } else if (val == 'top') {
            _sortBy = 'successRate';
            _descending = true;
          }
        });
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'new',
          child: Row(
            children: [
              Icon(Icons.history, size: 20, color: Colors.white70),
              SizedBox(width: 8),
              Text("En Yeni", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'old',
          child: Row(
            children: [
              Icon(Icons.first_page, size: 20, color: Colors.white70),
              SizedBox(width: 8),
              Text("En Eski", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'top',
          child: Row(
            children: [
              Icon(Icons.star_rounded, size: 20, color: Colors.orangeAccent),
              SizedBox(width: 8),
              Text("En Başarılı", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  // --- TEST GEÇMİŞİ LİSTESİ ---
  Widget _buildTestHistoryList(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('test_history')
          .orderBy(_sortBy, descending: _descending)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
          );
        }

        final tests = snapshot.data!.docs;
        if (tests.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Text(
                "Henüz test çözmedin.",
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final doc = tests[index];
              final data = doc.data() as Map<String, dynamic>;
              int displayNo = _descending ? tests.length - index : index + 1;

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (dir) async {
                  return await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      title: const Text("Testi Sil?", style: TextStyle(color: Colors.white)),
                      content: Text(
                        "Bu test silinecek ve genel puanlarınızdan düşülecek. Emin misiniz?",
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text("İptal", style: TextStyle(color: Colors.white.withOpacity(0.5))),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            "Sil",
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (dir) => _deleteTest(uid, doc.id, data),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 15),
                    ],
                  ),
                  child: const Icon(
                    Icons.delete_sweep_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                child: _buildHistoryItem(data, displayNo),
              );
            }, childCount: tests.length),
          ),
        );
      },
    );
  }

  // --- KART TASARIMI (Glassmorphism) ---
  Widget _buildHistoryItem(Map<String, dynamic> data, int testNo) {
    double rate = (data['successRate'] ?? 0).toDouble();
    Color statusColor = rate >= 80
        ? Colors.tealAccent
        : (rate >= 50 ? Colors.orangeAccent : Colors.redAccent);

    // --- TARİH VE SAAT FORMATI ---
    String dateStr = "Tarih Yok";
    if (data['timestamp'] != null) {
      DateTime dt = (data['timestamp'] as Timestamp).toDate();
      String gun = dt.day.toString().padLeft(2, '0');
      String ay = dt.month.toString().padLeft(2, '0');
      String saat = dt.hour.toString().padLeft(2, '0');
      String dakika = dt.minute.toString().padLeft(2, '0');
      dateStr = "$gun.$ay.${dt.year} • $saat:$dakika";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.7), // Glass background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Sol Taraftaki Parlayan Renk Şeridi
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(color: statusColor, blurRadius: 10, spreadRadius: -2),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Test Görevi #$testNo",
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildMiniChip(
                            Icons.check_circle_rounded,
                            "${data['correct']}",
                            Colors.tealAccent,
                          ),
                          const SizedBox(width: 8),
                          _buildMiniChip(
                            Icons.cancel_rounded,
                            "${data['wrong']}",
                            Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          _buildMiniChip(
                            Icons.school_rounded,
                            "${data['mastered'] ?? 0}",
                            Colors.purpleAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _buildRateIndicator(rate, statusColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRateIndicator(double rate, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: color.withOpacity(0.1)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "%${rate.toStringAsFixed(0)}",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 10)],
            ),
          ),
          Text(
            "Başarı",
            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(IconData icon, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            val,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStatCard(
    String title,
    String val,
    IconData icon,
    List<Color> colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.8), size: 30),
          const SizedBox(height: 15),
          Text(
            val,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordStats(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('words')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final docs = snapshot.data!.docs;
        int learned = docs
            .where((d) => (d.data() as Map)['isLearned'] == true)
            .length;
        int inPool = docs
            .where((d) => (d.data() as Map)['isLearned'] != true)
            .length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _buildMainStatCard(
                  "Öğrenilen",
                  "$learned",
                  Icons.auto_awesome,
                  [Colors.orangeAccent, Colors.deepOrangeAccent],
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildMainStatCard(
                  "Havuzda",
                  "$inPool",
                  Icons.layers_rounded,
                  [Colors.blueAccent, Colors.indigoAccent],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackButton() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  // --- ARKA PLAN (AURA) ---
  Widget _buildBackgroundDecor() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.purpleAccent.withOpacity(0.15), Colors.transparent],
                stops: const [0.1, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.blueAccent.withOpacity(0.15), Colors.transparent],
                stops: const [0.1, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
