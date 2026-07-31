import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/services.dart';
import '../services/subscription_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;
  String _currentPlan = 'basic';
  String? _activeProductId;
  Offerings? _offerings;
  final SubscriptionService _subService = SubscriptionService();

  // Tab State
  String _selectedTab = 'pro'; // 'plus', 'pro', 'max'
  String _selectedDuration = 'annual'; // 'monthly', 'annual'

  @override
  void initState() {
    super.initState();
    _fetchCurrentPlan();
    _fetchOfferings();
  }

  Future<void> _fetchOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (mounted && offerings.current != null) {
        setState(() {
          _offerings = offerings;
        });
      }
    } catch (e) {
      debugPrint("RevenueCat Error: $e");
    }
  }

  Future<void> _fetchCurrentPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('subscriptionPlan')) {
        if (mounted) {
          setState(() {
            _currentPlan = doc.data()!['subscriptionPlan'];
          });
        }
      }
    }

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      if (customerInfo.activeSubscriptions.isNotEmpty && mounted) {
        setState(() {
          _activeProductId = customerInfo.activeSubscriptions.first
              .toLowerCase();
        });
      }
    } catch (e) {}
  }

  Future<void> _purchasePlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      // 1. Try to use RevenueCat if available
      if (_offerings != null && _offerings!.current != null) {
        Package? packageToBuy;

        // Find package based on selected Tab and Duration
        try {
          packageToBuy = _offerings!.current!.availablePackages.firstWhere((p) {
            final id = p.identifier.toLowerCase();
            final isTargetTab = id.contains(_selectedTab);
            final isTargetDuration = _selectedDuration == 'annual'
                ? (id.contains('annual') || id.contains('yillik'))
                : (id.contains('monthly') || id.contains('aylik'));
            return isTargetTab && isTargetDuration;
          });
        } catch (e) {
          // Fallback to first available if exact match not found
          if (_offerings!.current!.availablePackages.isNotEmpty) {
            packageToBuy = _offerings!.current!.availablePackages.first;
          }
        }

        if (packageToBuy != null) {
          final customerInfo = await Purchases.getCustomerInfo();
          String? oldProductId;
          if (customerInfo.activeSubscriptions.isNotEmpty) {
            oldProductId = customerInfo.activeSubscriptions.first;
          }

          if (oldProductId != null && Platform.isAndroid) {
            // Google Play'de aynı ana aboneliğin alt paketleri (Aylık/Yıllık) arasında geçiş yapılıyorsa
            // GoogleProductChangeInfo gönderilMEMELİDİR. Sadece farklı paketlere (Plus -> Pro) geçerken gönderilir.
            final oldGroup = oldProductId.split(':').first;
            final newGroup = packageToBuy.storeProduct.identifier
                .split(':')
                .first;

            if (oldGroup == newGroup) {
              // Aynı paketin Süre (Aylık <-> Yıllık) değişimi
              await Purchases.purchasePackage(packageToBuy);
            } else {
              // Tamamen farklı bir pakete Yükseltme/Düşürme
              await Purchases.purchasePackage(
                packageToBuy,
                googleProductChangeInfo: GoogleProductChangeInfo(
                  oldProductId,
                  prorationMode: GoogleProrationMode.immediateWithTimeProration,
                ),
              );
            }
          } else {
            await Purchases.purchasePackage(packageToBuy);
          }

          await _subService.syncRevenueCatStatus();
          await _fetchCurrentPlan();

          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Tebrikler! ${_selectedTab.toUpperCase()} paketine yükseltildiniz! 🎉',
                ),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          }
          return;
        }
      }

      // 2. Fallback Mock (If API keys not yet set or products missing)
      await Future.delayed(const Duration(seconds: 1));
      await _subService.upgradeSubscription(_selectedTab);

      if (mounted) {
        setState(() {
          _currentPlan = _selectedTab;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tebrikler! ${_selectedTab.toUpperCase()} paketine yükseltildiniz! (Test) 🎉',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errorCode = PurchasesErrorHelper.getErrorCode(e);
        if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
          // Sessiz iptal
          return;
        }

        String errorMessage =
            'Ödeme işlemi iptal edildi veya bir sorun oluştu.';
        Color bgColor = Colors.redAccent;

        switch (errorCode) {
          case PurchasesErrorCode.productAlreadyPurchasedError:
            errorMessage = 'Bu pakete zaten sahipsiniz! 🔒';
            bgColor = Colors.orangeAccent;
            break;
          case PurchasesErrorCode.paymentPendingError:
            errorMessage =
                'Ödemeniz şu anda beklemede. Bankanız onayladığında paketiniz aktifleşecek. ⏳';
            bgColor = Colors.orangeAccent;
            break;
          case PurchasesErrorCode.networkError:
            errorMessage =
                'İnternet bağlantınızı kontrol edip tekrar deneyin. 📶';
            break;
          case PurchasesErrorCode.receiptAlreadyInUseError:
            errorMessage =
                'Bu satın alma işlemi zaten başka bir hesapta kullanılıyor. 👤';
            break;
          case PurchasesErrorCode.storeProblemError:
            errorMessage =
                'Mağaza tarafında geçici bir sorun var. Lütfen daha sonra tekrar deneyin. 🏪';
            break;
          case PurchasesErrorCode.purchaseNotAllowedError:
            errorMessage =
                'Cihazınızda satın alma işlemleri kısıtlanmış olabilir. 🚫';
            break;
          case PurchasesErrorCode.productNotAvailableForPurchaseError:
            errorMessage = 'Bu paket şu anda satın alınamıyor. ❌';
            break;
          case PurchasesErrorCode.purchaseInvalidError:
            errorMessage = 'Satın alma işlemi doğrulanamadı veya geçersiz. ⚠️';
            break;
          default:
            errorMessage =
                'Ödeme sırasında bir hata oluştu. Lütfen tekrar deneyin.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: bgColor),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Beklenmeyen bir hata oluştu.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    try {
      final customerInfo = await Purchases.restorePurchases();

      if (customerInfo.entitlements.active.isNotEmpty) {
        await _subService.syncRevenueCatStatus();
        await _fetchCurrentPlan();
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Satın alımlarınız başarıyla geri yüklendi! 🎒'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Geçmiş tarihli aktif bir VIP planınız bulunamadı. 🔍',
              ),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geri yükleme işlemi başarısız oldu.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // MARK: - UI Helpers

  int _getTier(String plan) {
    switch (plan.toLowerCase()) {
      case 'max':
        return 3;
      case 'pro':
        return 2;
      case 'plus':
        return 1;
      default:
        return 0;
    }
  }

  Map<String, dynamic> _getTabData(String tab) {
    final plusL = SubscriptionService.limits['plus']!;
    final proL = SubscriptionService.limits['pro']!;
    final maxL = SubscriptionService.limits['max']!;

    String formatLimit(int limit) =>
        limit == 999999 ? 'Sınırsız' : limit.toString();
    String formatWords(int limit) =>
        limit == 999999 ? 'Sınırsız' : limit.toString();

    if (tab == 'plus') {
      return {
        'name': 'Owlish Plus',
        'color': const Color(0xFF3B82F6),
        'accent': const Color(0xFF60A5FA),
        'icon': Icons.star_border,
        'features': [
          _buildFeatureRow(
            Icons.add_circle,
            '${formatWords(plusL['lifetimeWordsAdded']!)} Kelime Havuzu Kapasitesi',
            Colors.blueAccent,
          ),
          _buildFeatureRow(
            Icons.auto_stories,
            'Günde ${formatLimit(plusL['storyGenCount']!)} Yeni Yapay Zeka Hikayesi',
            Colors.blueAccent,
          ),
          _buildFeatureRow(
            Icons.library_books,
            'Günde ${formatLimit(plusL['storyReadCount']!)} Havuzdan Hikaye Okuma',
            Colors.blueAccent,
          ),
          _buildFeatureRow(
            Icons.chat,
            'Günde ${formatLimit(plusL['chatMsgCount']!)} OwlishAI Sohbet Mesajı',
            Colors.blueAccent,
          ),
          _buildFeatureRow(
            Icons.translate,
            'Günde ${formatLimit(plusL['translateCount']!)} Çeviri Hakkı',
            Colors.blueAccent,
          ),
          _buildFeatureRow(
            Icons.school,
            'Günde ${formatLimit(plusL['testCount']!)} Kelime Testi Soru Hakkı',
            Colors.blueAccent,
          ),
        ],
        'fallbackMonthlyPrice': '₺99.99',
        'fallbackAnnualPrice': '₺599.99',
      };
    } else if (tab == 'pro') {
      return {
        'name': 'Owlish Pro',
        'color': const Color(0xFF8B5CF6),
        'accent': const Color(0xFFC084FC),
        'icon': Icons.star,
        'features': [
          _buildFeatureRow(
            Icons.add_circle,
            '${formatWords(proL['lifetimeWordsAdded']!)} Kelime Havuzu Kapasitesi',
            Colors.purpleAccent,
          ),
          _buildFeatureRow(
            Icons.auto_stories,
            'Günde ${formatLimit(proL['storyGenCount']!)} Yeni Yapay Zeka Hikayesi',
            Colors.purpleAccent,
          ),
          _buildFeatureRow(
            Icons.library_books,
            'Günde ${formatLimit(proL['storyReadCount']!)} Havuzdan Hikaye Okuma',
            Colors.purpleAccent,
          ),
          _buildFeatureRow(
            Icons.chat,
            'Günde ${formatLimit(proL['chatMsgCount']!)} OwlishAI Sohbet Mesajı',
            Colors.purpleAccent,
          ),
          _buildFeatureRow(
            Icons.translate,
            'Günde ${formatLimit(proL['translateCount']!)} Çeviri Hakkı',
            Colors.purpleAccent,
          ),
          _buildFeatureRow(
            Icons.school,
            'Günde ${formatLimit(proL['testCount']!)} Kelime Testi Soru Hakkı',
            Colors.purpleAccent,
          ),
        ],
        'fallbackMonthlyPrice': '₺199.99',
        'fallbackAnnualPrice': '₺1199.99',
      };
    } else {
      return {
        'name': 'Owlish Max',
        'color': const Color(0xFFF59E0B),
        'accent': const Color(0xFFFCD34D),
        'icon': Icons.workspace_premium,
        'features': [
          _buildFeatureRow(
            Icons.all_inclusive,
            '${formatWords(maxL['lifetimeWordsAdded']!)} Kelime Havuzu Kapasitesi',
            Colors.amberAccent,
          ),
          _buildFeatureRow(
            Icons.auto_stories,
            '${maxL['storyGenCount'] == 999999 ? 'Sınırsız' : 'Günde ${maxL['storyGenCount']}'} Yeni Yapay Zeka Hikayesi',
            Colors.amberAccent,
          ),
          _buildFeatureRow(
            Icons.library_books,
            '${maxL['storyReadCount'] == 999999 ? 'Sınırsız' : 'Günde ${maxL['storyReadCount']}'} Havuzdan Hikaye Okuma',
            Colors.amberAccent,
          ),
          _buildFeatureRow(
            Icons.chat,
            '${maxL['chatMsgCount'] == 999999 ? 'Sınırsız' : 'Günde ${maxL['chatMsgCount']}'} OwlishAI Sohbet Mesajı',
            Colors.amberAccent,
          ),
          _buildFeatureRow(
            Icons.translate,
            '${maxL['translateCount'] == 999999 ? 'Sınırsız' : 'Günde ${maxL['translateCount']}'} Çeviri Hakkı',
            Colors.amberAccent,
          ),
          _buildFeatureRow(
            Icons.school,
            '${maxL['testCount'] == 999999 ? 'Sınırsız' : 'Günde ${maxL['testCount']}'} Kelime Testi Soru Hakkı',
            Colors.amberAccent,
          ),
        ],
        'fallbackMonthlyPrice': '₺399.99',
        'fallbackAnnualPrice': '₺2399.99',
      };
    }
  }

  Widget _buildFeatureRow(IconData icon, String text, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabId, String title, Color color) {
    final isSelected = _selectedTab == tabId;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tabId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildDurationCard({
    required String durationId,
    required String title,
    required String subtitle,
    required String priceStr,
    required Color activeColor,
    bool isPopular = false,
  }) {
    final isSelected = _selectedDuration == durationId;

    return GestureDetector(
      onTap: () => setState(() => _selectedDuration = durationId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.15)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (isPopular)
              Positioned(
                top: -26,
                right: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'EN AVANTAJLI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected ? activeColor : Colors.white30,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  priceStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        color: activeColor.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabData = _getTabData(_selectedTab);
    final themeColor = tabData['color'] as Color;

    final currentTier = _getTier(_currentPlan);
    final selectedTier = _getTier(_selectedTab);

    bool isDowngrade = selectedTier < currentTier;
    bool isExactSame = false;

    // Alt ve üst paket süre analizi (Aylık vs Yıllık)
    if (_activeProductId != null &&
        _activeProductId!.contains(_selectedTab.toLowerCase())) {
      final isTargetAnnual = _selectedDuration == 'annual';
      final isActiveAnnual =
          _activeProductId!.contains('annual') ||
          _activeProductId!.contains('yillik');

      if (isTargetAnnual == isActiveAnnual) {
        isExactSame = true; // Birebir aynı ürün
      } else if (isActiveAnnual && !isTargetAnnual) {
        isDowngrade = true; // Yıllıktan aylığa düşüş
      }
    }

    // Dinamik Fiyat Okuma Mantığı (RevenueCat Yoksa Fallback)
    String monthlyPrice = tabData['fallbackMonthlyPrice'];
    String annualPrice = tabData['fallbackAnnualPrice'];

    // RevenueCat'ten paket gelirse burası dolacak:
    // (Şu an ürünler Google Play'e eklenmediği için boş olacaktır)
    if (_offerings != null && _offerings!.current != null) {
      for (var pkg in _offerings!.current!.availablePackages) {
        final id = pkg.identifier.toLowerCase();
        if (id.contains(_selectedTab)) {
          if (id.contains('monthly') || id.contains('aylik')) {
            monthlyPrice = pkg.storeProduct.priceString;
          } else if (id.contains('annual') || id.contains('yillik')) {
            annualPrice = pkg.storeProduct.priceString;
          }
        }
      }
    }

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
          // Background Blobs
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: themeColor.withOpacity(0.2),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Planınızı Seçin",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: themeColor.withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "İstediğiniz zaman iptal edebilirsiniz.",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _buildTabButton('plus', 'Plus', const Color(0xFF3B82F6)),
                      const SizedBox(width: 12),
                      _buildTabButton('pro', 'Pro', const Color(0xFF8B5CF6)),
                      const SizedBox(width: 12),
                      _buildTabButton('max', 'Max', const Color(0xFFF59E0B)),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Main Card
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                tabData['icon'],
                                color: themeColor,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                tabData['name'],
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Features List
                          ...List.generate(
                            (tabData['features'] as List).length,
                            (index) =>
                                (tabData['features'] as List)[index] as Widget,
                          ),

                          const SizedBox(height: 30),

                          // Duration Selectors
                          _buildDurationCard(
                            durationId: 'monthly',
                            title: '1 Aylık',
                            subtitle: 'Esnek ödeme',
                            priceStr: monthlyPrice,
                            activeColor: themeColor,
                          ),
                          const SizedBox(height: 16),
                          _buildDurationCard(
                            durationId: 'annual',
                            title: '12 Aylık',
                            subtitle: 'Aylığa göre %50 tasarruf edin!',
                            priceStr: annualPrice,
                            activeColor: themeColor,
                            isPopular: true,
                          ),

                          const SizedBox(height: 30),

                          // Action Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: isExactSame
                                  ? null
                                  : () {
                                      if (isDowngrade) {
                                        _launchURL(
                                          Platform.isIOS
                                              ? 'https://apps.apple.com/account/subscriptions'
                                              : 'https://play.google.com/store/account/subscriptions',
                                        );
                                      } else {
                                        _purchasePlan();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDowngrade
                                    ? Colors.grey.shade800
                                    : themeColor,
                                foregroundColor: Colors.white,
                                elevation: isExactSame ? 0 : 8,
                                shadowColor: themeColor.withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                disabledBackgroundColor: Colors.grey.shade800,
                                disabledForegroundColor: Colors.white54,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (!isDowngrade && !isExactSame)
                                          const Icon(
                                            Icons.lock,
                                            size: 16,
                                            color: Colors.white70,
                                          ),
                                        if (!isDowngrade && !isExactSame)
                                          const SizedBox(width: 8),
                                        Text(
                                          isExactSame
                                              ? 'Mevcut Planınız (Aktif)'
                                              : (isDowngrade
                                                    ? 'Aboneliği Yönet / Düşür'
                                                    : 'Güvenli Ödeme ile ${_selectedDuration == 'annual' ? '12 Aylık' : '1 Aylık'} Al'),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Restore Purchases
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _restorePurchases,
                                  child: const Text(
                                    "Satın Alımları Geri Yükle (Restore Purchases)",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                const Text(
                                  "Önceden aktif bir aboneliğiniz varsa veya hesabınızı silip yeniden kayıt olduysanız VIP paketinizi buradan geri çağırabilirsiniz.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Legal Links (MAĞAZA ZORUNLULUĞU)
                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              children: [
                                GestureDetector(
                                  onTap: () => _launchURL(
                                    'https://sites.google.com/view/owlishprivacypolicy/ana-sayfa',
                                  ),
                                  child: const Text(
                                    "Gizlilik Politikası",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const Text(
                                  "|",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _launchURL(
                                    'https://sites.google.com/view/owlish-terms-of-use/ana-sayfa',
                                  ),
                                  child: const Text(
                                    "Kullanım Şartları",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30), // Safe area bottom
                        ],
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
}
