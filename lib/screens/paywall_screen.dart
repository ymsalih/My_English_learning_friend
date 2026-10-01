import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

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
                backgroundColor: AppColors.successFill,
              ),
            );
            Navigator.pop(context, true);
          }
          return;
        }
      }

      // 2. Paketler yüklenemedi. Yayın sürümünde ASLA ödemesiz yükseltme
      // yapılmaz (bağlantı/billing sorununda plan bedavaya açılıyordu).
      if (!kDebugMode) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ödeme sistemi şu an kullanılamıyor. Lütfen internet bağlantını kontrol edip tekrar dene.'),
              backgroundColor: AppColors.dangerFill,
            ),
          );
        }
        return;
      }

      // Yalnızca geliştirme sürümü: ürünler mağazada yokken test yükseltmesi.
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
            backgroundColor: AppColors.successFill,
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
        Color bgColor = AppColors.danger;

        switch (errorCode) {
          case PurchasesErrorCode.productAlreadyPurchasedError:
            errorMessage = 'Bu pakete zaten sahipsiniz! 🔒';
            bgColor = AppColors.gold;
            break;
          case PurchasesErrorCode.paymentPendingError:
            errorMessage =
                'Ödemeniz şu anda beklemede. Bankanız onayladığında paketiniz aktifleşecek. ⏳';
            bgColor = AppColors.gold;
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
            backgroundColor: AppColors.dangerFill,
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
              backgroundColor: AppColors.successFill,
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
              backgroundColor: AppColors.goldFill,
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
            backgroundColor: AppColors.dangerFill,
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
        'name': 'Octopus Plus',
        'color': AppColors.secondary,
        'accent': AppColors.secondary,
        'icon': Icons.star_border,
        'features': [
          _buildFeatureRow(
            Icons.add_circle,
            '${formatWords(plusL['lifetimeWordsAdded']!)} Kelime Havuzu Kapasitesi',
            AppColors.secondary,
          ),
          _buildFeatureRow(
            Icons.auto_stories,
            'Günde ${formatLimit(plusL['storyGenCount']!)} Yeni Yapay Zeka Hikayesi',
            AppColors.secondary,
          ),
          _buildFeatureRow(
            Icons.library_books,
            'Günde ${formatLimit(plusL['storyReadCount']!)} Havuzdan Hikaye Okuma',
            AppColors.secondary,
          ),
          _buildFeatureRow(
            Icons.chat,
            'Günde ${formatLimit(plusL['chatMsgCount']!)} Octopus AI Sohbet Mesajı',
            AppColors.secondary,
          ),
          _buildFeatureRow(
            Icons.translate,
            'Günde ${formatLimit(plusL['translateCount']!)} Çeviri Hakkı',
            AppColors.secondary,
          ),
          _buildFeatureRow(
            Icons.school,
            'Günde ${formatLimit(plusL['testCount']!)} Kelime Testi Soru Hakkı',
            AppColors.secondary,
          ),
        ],
        'fallbackMonthlyPrice': '₺99.99',
        'fallbackAnnualPrice': '₺599.99',
      };
    } else if (tab == 'pro') {
      return {
        'name': 'Octopus Pro',
        'color': AppColors.primary,
        'accent': AppColors.primaryLight,
        'icon': Icons.star,
        'features': [
          _buildFeatureRow(
            Icons.add_circle,
            '${formatWords(proL['lifetimeWordsAdded']!)} Kelime Havuzu Kapasitesi',
            AppColors.primaryLight,
          ),
          _buildFeatureRow(
            Icons.auto_stories,
            'Günde ${formatLimit(proL['storyGenCount']!)} Yeni Yapay Zeka Hikayesi',
            AppColors.primaryLight,
          ),
          _buildFeatureRow(
            Icons.library_books,
            'Günde ${formatLimit(proL['storyReadCount']!)} Havuzdan Hikaye Okuma',
            AppColors.primaryLight,
          ),
          _buildFeatureRow(
            Icons.chat,
            'Günde ${formatLimit(proL['chatMsgCount']!)} Octopus AI Sohbet Mesajı',
            AppColors.primaryLight,
          ),
          _buildFeatureRow(
            Icons.translate,
            'Günde ${formatLimit(proL['translateCount']!)} Çeviri Hakkı',
            AppColors.primaryLight,
          ),
          _buildFeatureRow(
            Icons.school,
            'Günde ${formatLimit(proL['testCount']!)} Kelime Testi Soru Hakkı',
            AppColors.primaryLight,
          ),
        ],
        'fallbackMonthlyPrice': '₺199.99',
        'fallbackAnnualPrice': '₺1199.99',
      };
    } else {
      return {
        'name': 'Octopus Max',
        'color': AppColors.gold,
        'accent': AppColors.gold,
        'icon': Icons.workspace_premium,
        'features': [
          _buildFeatureRow(
            Icons.all_inclusive,
            '${formatWords(maxL['lifetimeWordsAdded']!)} Kelime Havuzu Kapasitesi',
            AppColors.gold,
          ),
          _buildFeatureRow(
            Icons.auto_stories,
            '${maxL['storyGenCount'] == 999999 ? 'Sınırsız' : 'Günde ${maxL['storyGenCount']}'} Yeni Yapay Zeka Hikayesi',
            AppColors.gold,
          ),
          _buildFeatureRow(
            Icons.library_books,
            '${maxL['storyReadCount'] == 999999 ? 'Sınırsız' : 'Günde ${maxL['storyReadCount']}'} Havuzdan Hikaye Okuma',
            AppColors.gold,
          ),
          _buildFeatureRow(
            Icons.chat,
            '${maxL['chatMsgCount'] == 999999 ? 'Sınırsız' : 'Günde ${maxL['chatMsgCount']}'} Octopus AI Sohbet Mesajı',
            AppColors.gold,
          ),
          _buildFeatureRow(
            Icons.translate,
            '${maxL['translateCount'] == 999999 ? 'Sınırsız' : 'Günde ${maxL['translateCount']}'} Çeviri Hakkı',
            AppColors.gold,
          ),
          _buildFeatureRow(
            Icons.school,
            '${maxL['testCount'] == 999999 ? 'Sınırsız' : 'Günde ${maxL['testCount']}'} Kelime Testi Soru Hakkı',
            AppColors.gold,
          ),
        ],
        'fallbackMonthlyPrice': '₺399.99',
        'fallbackAnnualPrice': '₺2399.99',
      };
    }
  }

  Widget _buildFeatureRow(IconData icon, String text, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Icon(Icons.check_rounded, color: AppColors.success, size: 18),
        ],
      ),
    );
  }

  Widget _buildPlanSelector() {
    const plans = [('plus', 'Plus'), ('pro', 'Pro'), ('max', 'Max')];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final (id, title) in plans)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _selectedTab == id ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _selectedTab == id ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (id == 'pro') ...[
                        const SizedBox(width: 6),
                        Icon(Icons.local_fire_department_rounded, size: 14, color: AppColors.gold),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.14) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primaryLight : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      if (isPopular) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'EN AVANTAJLI',
                            style: TextStyle(color: AppColors.bg, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          color: isPopular ? AppColors.success : AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(priceStr, style: AppText.heading(size: 19)),
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
    double? rawMonthly;
    double? rawAnnual;

    // RevenueCat'ten paket gelirse burası dolacak:
    // (Şu an ürünler Google Play'e eklenmediği için boş olacaktır)
    if (_offerings != null && _offerings!.current != null) {
      for (var pkg in _offerings!.current!.availablePackages) {
        final id = pkg.identifier.toLowerCase();
        if (id.contains(_selectedTab)) {
          if (id.contains('monthly') || id.contains('aylik')) {
            monthlyPrice = pkg.storeProduct.priceString;
            rawMonthly = pkg.storeProduct.price;
          } else if (id.contains('annual') || id.contains('yillik')) {
            annualPrice = pkg.storeProduct.priceString;
            rawAnnual = pkg.storeProduct.price;
          }
        }
      }
    }

    String discountText = 'Aylığa göre tasarruf edin!';
    if (rawMonthly != null && rawAnnual != null && rawMonthly > 0) {
      double expectedAnnual = rawMonthly * 12;
      if (expectedAnnual > rawAnnual) {
        double discount = ((expectedAnnual - rawAnnual) / expectedAnnual * 100);
        String discountStr = discount.toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',');
        discountText = 'Aylığa göre %$discountStr tasarruf edin!';
      }
    } else {
      try {
        double m = double.parse(monthlyPrice.replaceAll(RegExp(r'[^0-9]'), ''));
        double a = double.parse(annualPrice.replaceAll(RegExp(r'[^0-9]'), ''));
        if (m > 0) {
          double expectedA = m * 12;
          if (expectedA > a) {
            double discount = ((expectedA - a) / expectedA * 100);
            String discountStr = discount.toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',');
            discountText = 'Aylığa göre %$discountStr tasarruf edin!';
          }
        }
      } catch (_) {}
    }

    final String ctaText = isExactSame
        ? 'Mevcut Planınız (Aktif)'
        : (isDowngrade
            ? 'Aboneliği Yönet / Düşür'
            : '${_selectedDuration == 'annual' ? '12 Aylık' : '1 Aylık'} ${tabData['name']} Al');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xxl),
            children: [
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 2),
                  ),
                  child: Image.asset('assets/logo_transparent.png'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Octopus Premium', textAlign: TextAlign.center, style: AppText.display(size: 28)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Daha fazla pratik, daha hızlı ilerleme.\nİstediğin zaman iptal edebilirsin.',
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
              const SizedBox(height: AppSpacing.xxl),
              _buildPlanSelector(),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconBadge(icon: tabData['icon'] as IconData, color: themeColor, size: 40),
                        const SizedBox(width: AppSpacing.md),
                        Text(tabData['name'], style: AppText.heading(size: 19)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    const SizedBox(height: AppSpacing.xs),
                    ...(tabData['features'] as List).cast<Widget>(),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildDurationCard(
                durationId: 'annual',
                title: '12 Aylık',
                subtitle: discountText,
                priceStr: annualPrice,
                activeColor: themeColor,
                isPopular: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildDurationCard(
                durationId: 'monthly',
                title: '1 Aylık',
                subtitle: 'Esnek ödeme',
                priceStr: monthlyPrice,
                activeColor: themeColor,
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _restorePurchases,
                  child: const Text("Satın Alımları Geri Yükle"),
                ),
              ),
              Text(
                "Önceden aktif bir aboneliğiniz varsa veya hesabınızı silip yeniden kayıt olduysanız paketinizi buradan geri çağırabilirsiniz.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.md),
              // Yasal bağlantılar (mağaza zorunluluğu)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                children: [
                  GestureDetector(
                    onTap: () => _launchURL('https://sites.google.com/view/owlishprivacypolicy/ana-sayfa'),
                    child: Text("Gizlilik Politikası", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ),
                  Text("|", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  GestureDetector(
                    onTap: () => _launchURL('https://sites.google.com/view/owlish-terms-of-use/ana-sayfa'),
                    child: Text("Kullanım Şartları", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      // Satın alma butonu her zaman görünür.
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.bgBottom,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: isExactSame || _isLoading
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
                  style: FilledButton.styleFrom(
                    backgroundColor: isDowngrade ? AppColors.surfaceHigh : AppColors.primary,
                    disabledBackgroundColor: AppColors.surfaceHigh,
                    disabledForegroundColor: AppColors.textMuted,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!isDowngrade && !isExactSame) ...[
                              const Icon(Icons.lock_rounded, size: 16),
                              const SizedBox(width: 8),
                            ],
                            Flexible(child: Text(ctaText, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Google Play / App Store ile güvenli ödeme',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
