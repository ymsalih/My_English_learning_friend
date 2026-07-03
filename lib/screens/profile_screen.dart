import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import '../services/subscription_service.dart';
import 'paywall_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SubscriptionService _subService = SubscriptionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _userName = "Öğrenci";
  String _userEmail = "";
  
  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  void _loadUserInfo() {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email ?? "";
        String fallbackName = user.displayName ?? _userEmail.split('@')[0];
        _userName = fallbackName.isNotEmpty
            ? fallbackName[0].toUpperCase() + fallbackName.substring(1)
            : "Öğrenci";
      });
    }
  }

  Future<void> _cancelSubscription() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Emin misiniz?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Aboneliğinizi iptal etmek üzeresiniz. İşlemi onaylarsanız 'Basic' (Ücretsiz) plana düşürüleceksiniz ve kısıtlamalarınız anında devreye girecek.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("İptal Et", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );

      await _subService.cancelSubscription();

      if (mounted) {
        Navigator.pop(context); // Close loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Aboneliğiniz iptal edildi. Basic plana döndünüz.", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.greenAccent.withAlpha(200),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(30)),
          ),
          child: child,
        ),
      ),
    );
  }

  String _getPlanName(String planKey) {
    switch (planKey.toLowerCase()) {
      case 'plus':
        return 'Plus';
      case 'pro':
        return 'Pro';
      case 'max':
        return 'Max';
      default:
        return 'Basic (Ücretsiz)';
    }
  }

  Color _getPlanColor(String planKey) {
    switch (planKey.toLowerCase()) {
      case 'plus':
        return Colors.blueAccent;
      case 'pro':
        return Colors.purpleAccent;
      case 'max':
        return Colors.amberAccent;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatRow(String label, Map<String, int>? data, IconData icon, Color color) {
    if (data == null) return const SizedBox.shrink();
    final current = data['current'] ?? 0;
    final limit = data['limit'] ?? 0;
    final isUnlimited = limit >= 999999;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          Text(
            isUnlimited ? "Sınırsız" : "$current / $limit",
            style: TextStyle(
              color: isUnlimited ? Colors.amberAccent : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Giriş yapılmadı.")));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Profilim", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
            }
            
            final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final planKey = userData['subscriptionPlan'] ?? 'basic';
            final planName = _getPlanName(planKey);
            final planColor = _getPlanColor(planKey);
            final isBasic = planKey == 'basic';

            final limitsMap = SubscriptionService.limits[planKey] ?? SubscriptionService.limits['basic']!;
            final dailyUsage = userData['dailyUsage'] as Map<String, dynamic>? ?? {};
            
            int safeInt(dynamic val) {
              if (val == null) return 0;
              if (val is num) return val.toInt();
              if (val is String) return int.tryParse(val) ?? 0;
              return 0;
            }

            final Map<String, Map<String, int>> limitsSummary = {
              'words': {
                'current': safeInt(userData['lifetimeWordsAdded']),
                'limit': safeInt(limitsMap['lifetimeWordsAdded'])
              },
              'storyGen': {
                'current': safeInt(dailyUsage['storyGenCount']),
                'limit': safeInt(limitsMap['storyGenCount'])
              },
              'storyRead': {
                'current': safeInt(dailyUsage['storyReadCount']),
                'limit': safeInt(limitsMap['storyReadCount'])
              },
              'chat': {
                'current': safeInt(dailyUsage['chatMsgCount']),
                'limit': safeInt(limitsMap['chatMsgCount'])
              },
              'translate': {
                'current': safeInt(dailyUsage['translateCount']),
                'limit': safeInt(limitsMap['translateCount'])
              },
              'test': {
                'current': safeInt(dailyUsage['testCount']),
                'limit': safeInt(limitsMap['testCount'])
              }
            };

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // User Profile Header
                  _buildGlassContainer(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: planColor.withAlpha(50),
                          child: Text(
                            _userName.isNotEmpty ? _userName[0] : "O",
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: planColor),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName,
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _userEmail,
                                style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Subscription Card
                  _buildGlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Mevcut Planınız",
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: planColor.withAlpha(40),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: planColor),
                              ),
                              child: Text(
                                planName,
                                style: TextStyle(color: planColor, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        _buildStatRow('Kelime Havuzu', limitsSummary['words'], Icons.book, Colors.blueAccent),
                        _buildStatRow('Hikaye Üretme', limitsSummary['storyGen'], Icons.edit, Colors.pinkAccent),
                        _buildStatRow('Hikaye Okuma', limitsSummary['storyRead'], Icons.menu_book, Colors.orangeAccent),
                        _buildStatRow('Yapay Zeka Chat', limitsSummary['chat'], Icons.chat, Colors.tealAccent),
                        _buildStatRow('Görsel Çeviri', limitsSummary['translate'], Icons.g_translate, Colors.greenAccent),
                        _buildStatRow('Kendini Test Et', limitsSummary['test'], Icons.psychology, Colors.purpleAccent),
                        
                        const SizedBox(height: 25),
                        
                        // Management Buttons
                        Row(
                          children: [
                            if (!isBasic) ...[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _cancelSubscription,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text("İptal Et"),
                                ),
                              ),
                              const SizedBox(width: 15),
                            ],
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PaywallScreen()));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isBasic ? Colors.purpleAccent : Colors.white24,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  isBasic ? "Planları İncele" : "Planı Yükselt",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
