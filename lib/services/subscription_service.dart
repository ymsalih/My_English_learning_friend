import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      'chatMsgCount': 7,
      'translateCount': 100,
      'testCount': 150,
    },
    'max': {
      'lifetimeWordsAdded': 999999, // Unlimited
      'storyGenCount': 8,
      'storyReadCount': 11,
      'chatMsgCount': 10,
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

  // Ensures dailyUsage exists and is for today. If not, resets it.
  Future<Map<String, dynamic>> _getValidDailyUsage(Map<String, dynamic> userData) async {
    final today = _getTodayString();
    Map<String, dynamic> dailyUsage = userData['dailyUsage'] ?? {};
    
    if (dailyUsage['date'] != today) {
      dailyUsage = {
        'date': today,
        'storyGenCount': 0,
        'storyReadCount': 0,
        'chatMsgCount': 0,
        'translateCount': 0,
        'testCount': 0,
      };
      
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
    final doc = await docRef.get();
    if (!doc.exists) return {};
    
    final data = doc.data() as Map<String, dynamic>;
    
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
      current = (data['lifetimeWordsAdded'] ?? 0) as int;
    } else {
      final dailyUsage = await _getValidDailyUsage(data);
      current = (dailyUsage[actionKey] ?? 0) as int;
    }
    
    final limit = (limits[plan]?[actionKey] ?? 0) as int;
    return current < limit;
  }

  Future<Map<String, int>> getActionUsage(String actionKey) async {
    final data = await _getUserData();
    if (data.isEmpty) return {'current': 0, 'limit': 0};
    
    final plan = data['subscriptionPlan'] ?? 'basic';
    
    int current = 0;
    if (actionKey == 'lifetimeWordsAdded') {
      current = (data['lifetimeWordsAdded'] ?? 0) as int;
    } else {
      final dailyUsage = await _getValidDailyUsage(data);
      current = (dailyUsage[actionKey] ?? 0) as int;
    }
    
    final limit = (limits[plan]?[actionKey] ?? 0) as int;
    
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
        'limit': (limits[plan]?['lifetimeWordsAdded'] ?? 50) as int
      },
      'storyGen': {
        'current': (dailyUsage['storyGenCount'] ?? 0) as int,
        'limit': (limits[plan]?['storyGenCount'] ?? 0) as int
      },
      'storyRead': {
        'current': (dailyUsage['storyReadCount'] ?? 0) as int,
        'limit': (limits[plan]?['storyReadCount'] ?? 0) as int
      },
      'chat': {
        'current': (dailyUsage['chatMsgCount'] ?? 0) as int,
        'limit': (limits[plan]?['chatMsgCount'] ?? 0) as int
      },
      'translate': {
        'current': (dailyUsage['translateCount'] ?? 0) as int,
        'limit': (limits[plan]?['translateCount'] ?? 0) as int
      },
      'test': {
        'current': (dailyUsage['testCount'] ?? 0) as int,
        'limit': (limits[plan]?['testCount'] ?? 0) as int
      }
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

  Future<void> incrementWordCount() async {
    final docRef = await _getUserDocRef();
    if (docRef != null) {
      await docRef.update({'lifetimeWordsAdded': FieldValue.increment(1)});
    }
  }

  Future<void> _incrementAction(String actionKey) async {
    final docRef = await _getUserDocRef();
    if (docRef != null) {
      // First ensure the day hasn't changed before incrementing
      final data = await _getUserData();
      await _getValidDailyUsage(data); 
      
      await docRef.update({'dailyUsage.$actionKey': FieldValue.increment(1)});
    }
  }

  Future<void> incrementStoryGen() => _incrementAction('storyGenCount');
  Future<void> incrementStoryRead() => _incrementAction('storyReadCount');
  Future<void> incrementChat() => _incrementAction('chatMsgCount');
  Future<void> incrementTranslate() => _incrementAction('translateCount');
  Future<void> incrementTest() => _incrementAction('testCount');

  Future<void> cancelSubscription() async {
    final docRef = await _getUserDocRef();
    if (docRef != null) {
      await docRef.set({
        'subscriptionPlan': 'basic',
      }, SetOptions(merge: true));
    }
  }

  Future<void> upgradeSubscription(String planId) async {
    final docRef = await _getUserDocRef();
    if (docRef != null) {
      await docRef.set({
        'subscriptionPlan': planId,
      }, SetOptions(merge: true));
    }
  }
}
