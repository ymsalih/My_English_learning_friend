import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import '../services/subscription_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;
  String _currentPlan = 'basic';
  final SubscriptionService _subService = SubscriptionService();

  @override
  void initState() {
    super.initState();
    _fetchCurrentPlan();
  }

  Future<void> _fetchCurrentPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('subscriptionPlan')) {
        setState(() {
          _currentPlan = doc.data()!['subscriptionPlan'];
        });
      }
    }
  }

  Future<void> _purchasePlan(String planId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      // Mock Purchase Logic
      await Future.delayed(const Duration(seconds: 1)); 
      
      // Update Firestore safely using SubscriptionService
      await _subService.upgradeSubscription(planId);

      if (mounted) {
        setState(() {
          _currentPlan = planId;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tebrikler! ${planId.toUpperCase()} paketine yükseltildiniz! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true indicating success
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildFeatureRow(IconData icon, String text, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String planId,
    required List<Widget> features,
    required Color primaryColor,
    required Color secondaryColor,
    bool isPopular = false,
  }) {
    final isCurrentPlan = _currentPlan == planId;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPopular ? primaryColor : Colors.white.withOpacity(0.1),
          width: isPopular ? 2 : 1,
        ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ]
            : [],
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.1),
            secondaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isPopular)
            Positioned(
              top: -12,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'EN POPÜLER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        shadows: [
                          Shadow(color: primaryColor.withOpacity(0.5), blurRadius: 10)
                        ],
                      ),
                    ),
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...features,
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isCurrentPlan
                        ? null
                        : () => _purchasePlan(planId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrentPlan ? Colors.grey.shade800 : primaryColor,
                      foregroundColor: Colors.white,
                      elevation: isPopular ? 8 : 2,
                      shadowColor: primaryColor.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            isCurrentPlan ? 'Mevcut Paketiniz' : 'Hemen Başla',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Elements
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withOpacity(0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withOpacity(0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Colors.amberAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Owlish Premium'u Keşfet",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Sınırları kaldırın ve İngilizce öğrenme hızınızı 10'a katlayın.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 40),

                  _buildPlanCard(
                    title: 'Owlish Plus',
                    price: '₺99/ay',
                    planId: 'plus',
                    primaryColor: const Color(0xFF3B82F6), // Blue
                    secondaryColor: const Color(0xFF60A5FA),
                    features: [
                      _buildFeatureRow(Icons.add_circle, '300 Kelime Havuzu Kapasitesi', Colors.blueAccent),
                      _buildFeatureRow(Icons.auto_stories, 'Günde 3 Yeni Yapay Zeka Hikayesi', Colors.blueAccent),
                      _buildFeatureRow(Icons.library_books, 'Günde 6 Havuzdan Hikaye Okuma', Colors.blueAccent),
                      _buildFeatureRow(Icons.chat, 'Günde 5 OwlishAI Sohbet Mesajı', Colors.blueAccent),
                      _buildFeatureRow(Icons.translate, 'Günde 50 Çeviri Hakkı', Colors.blueAccent),
                      _buildFeatureRow(Icons.school, 'Günde 80 Kelime Testi Soru Hakkı', Colors.blueAccent),
                    ],
                  ),

                  _buildPlanCard(
                    title: 'Owlish Pro',
                    price: '₺199/ay',
                    planId: 'pro',
                    isPopular: true,
                    primaryColor: const Color(0xFF8B5CF6), // Purple
                    secondaryColor: const Color(0xFFC084FC),
                    features: [
                      _buildFeatureRow(Icons.add_circle, '700 Kelime Havuzu Kapasitesi', Colors.purpleAccent),
                      _buildFeatureRow(Icons.auto_stories, 'Günde 5 Yeni Yapay Zeka Hikayesi', Colors.purpleAccent),
                      _buildFeatureRow(Icons.library_books, 'Günde 8 Havuzdan Hikaye Okuma', Colors.purpleAccent),
                      _buildFeatureRow(Icons.chat, 'Günde 7 OwlishAI Sohbet Mesajı', Colors.purpleAccent),
                      _buildFeatureRow(Icons.translate, 'Günde 100 Çeviri Hakkı', Colors.purpleAccent),
                      _buildFeatureRow(Icons.school, 'Günde 150 Kelime Testi Soru Hakkı', Colors.purpleAccent),
                    ],
                  ),

                  _buildPlanCard(
                    title: 'Owlish Max',
                    price: '₺399/ay',
                    planId: 'max',
                    primaryColor: const Color(0xFFF59E0B), // Amber
                    secondaryColor: const Color(0xFFFCD34D),
                    features: [
                      _buildFeatureRow(Icons.all_inclusive, 'Sınırsız Kelime Havuzu Kapasitesi', Colors.amberAccent),
                      _buildFeatureRow(Icons.auto_stories, 'Günde 8 Yeni Yapay Zeka Hikayesi', Colors.amberAccent),
                      _buildFeatureRow(Icons.library_books, 'Günde 11 Havuzdan Hikaye Okuma', Colors.amberAccent),
                      _buildFeatureRow(Icons.chat, 'Günde 10 OwlishAI Sohbet Mesajı', Colors.amberAccent),
                      _buildFeatureRow(Icons.all_inclusive, 'Sınırsız Çeviri Hakkı', Colors.amberAccent),
                      _buildFeatureRow(Icons.all_inclusive, 'Sınırsız Kelime Testi Soru Hakkı', Colors.amberAccent),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Text(
                    "İstediğiniz zaman iptal edebilirsiniz. Abonelikler, dönem sonunda otomatik olarak yenilenir.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
