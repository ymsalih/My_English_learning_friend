import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Limits Definition
  static const Map<String, Map<String, int>> limits = {
    'basic': {
      'lifetimeWordsAdded': 50,
      'storyGenCount': 1,
      'storyReadCount': 4,
      'chatMsgCount': 3,
      'translateCount': 20,
      'testCount': 40,
    },
    'plus': {
      'lifetimeWordsAdded': 300,
      'storyGenCount': 3,
      'storyReadCount': 6,
      'chatMsgCount': 5,
      'translateCount': 50,
      'testCount': 80,
    },
    'pro': {
      'lifetimeWordsAdded': 700,
      'storyGenCount': 5,
      'storyReadCount': 8,
      'chatMsgCount': 10,
      'translateCount': 100,
      'testCount': 150,
    },
    'max': {
      'lifetimeWordsAdded': 999999, // Unlimited
      'storyGenCount': 8,
      'storyReadCount': 11,
      'chatMsgCount': 20,
      'translateCount': 999999,
      'testCount': 999999,
    },
  };

  Future<DocumentReference?> _getUserDocRef() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid);
  }

  String _getTodayString() {
    return DateTime.now().toIso8601String().substring(0, 10);
  }

  Map<String, dynamic> _emptyDailyUsage(String today) => {
        'date': today,
        'storyGenCount': 0,
        'storyReadCount': 0,
        'chatMsgCount': 0,
        'translateCount': 0,
        'testCount': 0,
      };

  // --- KULLANICI BELGESİ ÖNBELLEĞİ ---
  // Tüm SubscriptionService örnekleri tek bir canlı dinleyiciyi paylaşır.
  // Limit kontrolleri her seferinde Firestore'a gitmek yerine bellekten okunur;
  // yazmalar (sayaç artışı vb.) dinleyiciye anında yansır.

  static String? _cachedUid;
  static Map<String, dynamic>? _cachedData;
  static Completer<void>? _firstSnapshot;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;
  static StreamSubscription<User?>? _authSub;

  void _ensureListening(String uid) {
    _authSub ??= _auth.authStateChanges().listen((user) {
      if (user?.uid != _cachedUid) _stopListening();
    });
    if (_cachedUid == uid && _docSub != null) return;

    _stopListening();
    _cachedUid = uid;
    final completer = _firstSnapshot = Completer<void>();
    _docSub = _firestore.collection('users').doc(uid).snapshots().listen(
      (snap) {
        _cachedData = snap.data() ?? {};
        if (!completer.isCompleted) completer.complete();
      },
      onError: (Object e) {
        debugPrint("Kullanıcı belgesi dinleme hatası: $e");
        if (!completer.isCompleted) completer.complete();
        _stopListening();
      },
    );
  }

  static void _stopListening() {
    _docSub?.cancel();
    _docSub = null;
    _cachedUid = null;
    _cachedData = null;
    _firstSnapshot = null;
  }

  /// Kullanıcı belgesinin güncel hali (önbellekten; gerekirse tek okuma).
  Future<Map<String, dynamic>> getUserData() => _getUserData();

  // Ensures dailyUsage exists and is for today. If not, resets it.
  Future<Map<String, dynamic>> _getValidDailyUsage(
    Map<String, dynamic> userData,
  ) async {
    final today = _getTodayString();
    Map<String, dynamic> dailyUsage = userData['dailyUsage'] ?? {};

    if (dailyUsage['date'] != today) {
      dailyUsage = _emptyDailyUsage(today);

      final docRef = await _getUserDocRef();
      if (docRef != null) {
        await docRef.update({'dailyUsage': dailyUsage});
      }
    }
    return dailyUsage;
  }

  Future<Map<String, dynamic>> _getUserData() async {
    final docRef = await _getUserDocRef();
    if (docRef == null) return {};

    _ensureListening(docRef.id);
    if (_cachedData == null) {
      // Yalnızca dinleyicinin ilk cevabı henüz gelmediyse beklenir.
      try {
        await _firstSnapshot?.future.timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    Map<String, dynamic>? cached = _cachedData;
    if (cached == null) {
      // Dinleyici kullanılamıyorsa eski yönteme (tek okuma) dön.
      final doc = await docRef.get();
      if (!doc.exists) return {};
      cached = doc.data() as Map<String, dynamic>;
    }
    if (cached.isEmpty) return {};

    // Önbelleği korumak için kopya üzerinde çalış.
    final data = Map<String, dynamic>.from(cached);

    // Migration for older users
    bool changed = false;
    if (!data.containsKey('subscriptionPlan')) {
      data['subscriptionPlan'] = data['isPro'] == true ? 'max' : 'basic';
      changed = true;
    }
    if (!data.containsKey('lifetimeWordsAdded')) {
      data['lifetimeWordsAdded'] = 0;
      changed = true;
    }
    if (!data.containsKey('dailyUsage')) {
      data['dailyUsage'] = {'date': _getTodayString()};
      changed = true;
    }

    if (changed) {
      await docRef.update({
        'subscriptionPlan': data['subscriptionPlan'],
        'lifetimeWordsAdded': data['lifetimeWordsAdded'],
        'dailyUsage': data['dailyUsage'],
      });
    }

    return data;
  }

  // --- CHECK METHODS ---

  Future<bool> canAddWord() async {
    final data = await _getUserData();
    if (data.isEmpty) return false;
    final plan = data['subscriptionPlan'] ?? 'basic';
    final current = data['lifetimeWordsAdded'] ?? 0;
    final limit = limits[plan]?['lifetimeWordsAdded'] ?? 50;
    return current < limit;
  }

  Future<bool> _canDoAction(String actionKey) async {
    final data = await _getUserData();
    if (data.isEmpty) return false;
    final plan = data['subscriptionPlan'] ?? 'basic';

    int current = 0;
    if (actionKey == 'lifetimeWordsAdded') {
      current = (data['lifetimeWordsAdded'] ?? 0);
    } else {
      final dailyUsage = await _getValidDailyUsage(data);
      current = (dailyUsage[actionKey] ?? 0);
    }

    final limit = (limits[plan]?[actionKey] ?? 0);
    return current < limit;
  }

  Future<Map<String, int>> getActionUsage(String actionKey) async {
    final data = await _getUserData();
    if (data.isEmpty) return {'current': 0, 'limit': 0};

    final plan = data['subscriptionPlan'] ?? 'basic';

    int current = 0;
    if (actionKey == 'lifetimeWordsAdded') {
      current = (data['lifetimeWordsAdded'] ?? 0);
    } else {
      final dailyUsage = await _getValidDailyUsage(data);
      current = (dailyUsage[actionKey] ?? 0);
    }

    final limit = (limits[plan]?[actionKey] ?? 0);

    return {'current': current, 'limit': limit};
  }

  Future<Map<String, Map<String, int>>> getLimitsSummary() async {
    final data = await _getUserData();
    if (data.isEmpty) return {};

    final plan = data['subscriptionPlan'] ?? 'basic';
    final dailyUsage = await _getValidDailyUsage(data);
    final lifetimeWordsAdded = data['lifetimeWordsAdded'] ?? 0;

    return {
      'words': {
        'current': lifetimeWordsAdded as int,
        'limit': limits[plan]?['lifetimeWordsAdded'] ?? 50,
      },
      'storyGen': {
        'current': dailyUsage['storyGenCount'] ?? 0,
        'limit': limits[plan]?['storyGenCount'] ?? 0,
      },
      'storyRead': {
        'current': dailyUsage['storyReadCount'] ?? 0,
        'limit': limits[plan]?['storyReadCount'] ?? 0,
      },
      'chat': {
        'current': dailyUsage['chatMsgCount'] ?? 0,
        'limit': limits[plan]?['chatMsgCount'] ?? 0,
      },
      'translate': {
        'current': dailyUsage['translateCount'] ?? 0,
        'limit': limits[plan]?['translateCount'] ?? 0,
      },
      'test': {
        'current': dailyUsage['testCount'] ?? 0,
        'limit': limits[plan]?['testCount'] ?? 0,
      },
    };
  }

  Future<bool> canGenerateStory() => _canDoAction('storyGenCount');
  Future<bool> canReadStory() => _canDoAction('storyReadCount');
  Future<bool> canChat() => _canDoAction('chatMsgCount');
  Future<bool> canTranslate() => _canDoAction('translateCount');
  Future<bool> canTest() => _canDoAction('testCount');

  Future<int> getRemainingTestCount() async {
    final usage = await getActionUsage('testCount');
    final current = usage['current'] ?? 0;
    final limit = usage['limit'] ?? 0;
    return limit - current;
  }

  // --- INCREMENT METHODS ---

  // Sayaç yazmaları sunucu onayı beklenmeden başlatılır: yerel önbellek ve
  // dinleyiciler değişikliği anında görür, Firestore yazmayı arka planda
  // (çevrimdışıysa bağlantı gelince) tamamlar. Ekranlar ağ gecikmesi yaşamaz.
  void _writeInBackground(Future<void> write) {
    write.catchError((Object e) => debugPrint("Sayaç yazma hatası: $e"));
  }

  Future<void> incrementWordCount() async {
    final docRef = await _getUserDocRef();
    if (docRef != null) {
      _writeInBackground(
        docRef.update({'lifetimeWordsAdded': FieldValue.increment(1)}),
      );
    }
  }

  Future<void> _incrementAction(String actionKey) async {
    final docRef = await _getUserDocRef();
    if (docRef != null) {
      final data = await _getUserData();
      final today = _getTodayString();
      final dailyUsage = data['dailyUsage'] as Map<String, dynamic>? ?? {};

      if (dailyUsage['date'] != today) {
        // Yeni gün: sıfırlama ve artırma tek yazmada.
        _writeInBackground(docRef.update({
          'dailyUsage': {..._emptyDailyUsage(today), actionKey: 1},
        }));
      } else {
        _writeInBackground(
          docRef.update({'dailyUsage.$actionKey': FieldValue.increment(1)}),
        );
      }
    }
  }

  Future<void> incrementStoryGen() => _incrementAction('storyGenCount');
  Future<void> incrementStoryRead() => _incrementAction('storyReadCount');
  Future<void> incrementChat() => _incrementAction('chatMsgCount');
  Future<void> incrementTranslate() => _incrementAction('translateCount');
  Future<void> incrementTest() => _incrementAction('testCount');

  // --- REVENUECAT SYNC ---

  void setupRevenueCatListener() {
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      syncRevenueCatStatus();
    });
  }

  Future<void> syncRevenueCatStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      String activePlan = 'basic';

      if (customerInfo.entitlements.active.isNotEmpty) {
        if (customerInfo.entitlements.active.containsKey('max')) {
          activePlan = 'max';
        } else if (customerInfo.entitlements.active.containsKey('pro')) {
          activePlan = 'pro';
        } else if (customerInfo.entitlements.active.containsKey('plus') ||
            customerInfo.entitlements.active.containsKey('premium')) {
          activePlan = 'plus';
        }
      }

      final docRef = await _getUserDocRef();
      if (docRef != null) {
        final data = await _getUserData();
        if (data['subscriptionPlan'] != activePlan) {
          await docRef.set({
            'subscriptionPlan': activePlan,
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint("RevenueCat sync error: $e");
    }
  }

  Future<void> cancelSubscription() async {
    // In RevenueCat, users must cancel via App Store / Google Play.
    // We just mock it here for testing if needed, or leave it as basic.
    final docRef = await _getUserDocRef();
    if (docRef != null) {
      await docRef.set({'subscriptionPlan': 'basic'}, SetOptions(merge: true));
    }
  }

  Future<void> upgradeSubscription(String planId) async {
    // This will now be handled by RevenueCat Purchases.purchasePackage in PaywallScreen.
    // Kept here for fallback/testing.
    final docRef = await _getUserDocRef();
    if (docRef != null) {
      await docRef.set({'subscriptionPlan': planId}, SetOptions(merge: true));
    }
  }
}
