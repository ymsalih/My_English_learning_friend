import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
          const SnackBar(
            content: Text("Test silindi, istatistikleriniz güncellendi."),
            backgroundColor: Colors.black87,
            behavior: SnackBarBehavior.floating,
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
      backgroundColor: const Color(0xFFF0F4FF),
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
                      color: Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
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
                          color: Colors.black87,
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
      icon: const Icon(Icons.tune_rounded, color: Colors.deepPurpleAccent),
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
              Icon(Icons.history, size: 20),
              SizedBox(width: 8),
              Text("En Yeni"),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'old',
          child: Row(
            children: [
              Icon(Icons.first_page, size: 20),
              SizedBox(width: 8),
              Text("En Eski"),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'top',
          child: Row(
            children: [
              Icon(Icons.star_rounded, size: 20, color: Colors.orange),
              SizedBox(width: 8),
              Text("En Başarılı"),
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
        if (!snapshot.hasData)
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );

        final tests = snapshot.data!.docs;
        if (tests.isEmpty)
          return const SliverFillRemaining(
            child: Center(
              child: Text(
                "Henüz test çözmedin.",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );

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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text("Testi Sil?"),
                      content: const Text(
                        "Bu test silinecek ve genel puanlarınızdan düşülecek. Emin misiniz?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("İptal"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            "Sil",
                            style: TextStyle(color: Colors.red),
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
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(24),
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

  // --- KART TASARIMI ---
  Widget _buildHistoryItem(Map<String, dynamic> data, int testNo) {
    double rate = (data['successRate'] ?? 0).toDouble();
    Color statusColor = rate >= 80
        ? Colors.teal
        : (rate >= 50 ? Colors.orange : Colors.redAccent);

    // --- GÜNCELLENDİ: TARİH VE SAAT FORMATI ---
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.08),
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
              Container(width: 6, color: statusColor),
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
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: Colors.grey.shade500,
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
                            Colors.teal,
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
                            Colors.deepPurpleAccent,
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
      decoration: BoxDecoration(color: color.withOpacity(0.05)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "%${rate.toStringAsFixed(0)}",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const Text(
            "Başarı",
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(IconData icon, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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
              fontSize: 12,
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
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.6), size: 30),
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
              color: Colors.white.withOpacity(0.8),
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
                  [Colors.orange.shade400, Colors.orange.shade700],
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildMainStatCard(
                  "Havuzda",
                  "$inPool",
                  Icons.layers_rounded,
                  [Colors.blue.shade400, Colors.blue.shade700],
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
        color: Colors.white.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.black87,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildBackgroundDecor() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -50,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: Colors.blue.shade50.withOpacity(0.5),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Colors.purple.shade50.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
