import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// For BackdropFilter if needed
import 'tts_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TtsService _ttsService = TtsService();

  double _currentRate = 0.55;
  double _currentPitch = 1.0;

  String _selectedLevel = 'A1';
  bool _isLoadingUser = true;
  final List<String> _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  final TextEditingController _testTextController = TextEditingController(
    text: "Hello, this is a test for the new voice settings.",
  );

  @override
  void initState() {
    super.initState();
    // Ekran açıldığında servisteki mevcut ayarları alıyoruz
    _currentRate = _ttsService.speechRate;
    _currentPitch = _ttsService.pitch;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _selectedLevel = doc.data()?['level'] ?? 'A1';
            _isLoadingUser = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingUser = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  @override
  void dispose() {
    _testTextController.dispose();
    super.dispose();
  }

  Future<void> _testVoice() async {
    // Test etmek için butona basıldığında güncel ayarları servise uygulayıp test metnini okutuyoruz
    await _ttsService.setRate(_currentRate);
    await _ttsService.setPitch(_currentPitch);
    await _ttsService.speak(_testTextController.text);
  }

  Future<void> _saveSettings() async {
    // Ayarları kalıcı olarak servise kaydediyoruz
    await _ttsService.setRate(_currentRate);
    await _ttsService.setPitch(_currentPitch);

    // Seviyeyi Firebase'e kaydediyoruz
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'level': _selectedLevel});
      } catch (e) {
        debugPrint("Seviye güncellenirken hata: $e");
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 10),
              Text("Ses ayarları başarıyla kaydedildi! ✨", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: Colors.purpleAccent.withOpacity(0.9), // Temaya Uygun SnackBar
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark Space Background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Genel Ayarlar',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // --- ARKA PLAN (AURA) ---
          Positioned(
            top: -50,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
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
            bottom: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.blueAccent.withOpacity(0.15), Colors.transparent],
                  stops: const [0.1, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- BİLGİ KARTI (Glassmorphism) ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.7), // Glass background
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.record_voice_over_rounded,
                            size: 28,
                            color: Colors.purpleAccent,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Text(
                            "Burada yaptığınız değişiklikler tüm uygulamadaki okuma hızını ve tonunu anında günceller.",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 35),

                  // --- İNGİLİZCE SEVİYESİ ---
                  if (!_isLoadingUser) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "İngilizce Seviyesi",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedLevel,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blueAccent),
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedLevel = newValue;
                                  });
                                }
                              },
                              items: _levels.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Yapay zeka asistanı içerik üretirken bu seviyeyi baz alacaktır.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],

                  // --- SES HIZI (RATE) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Okuma Hızı",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _currentRate.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.blueAccent,
                      inactiveTrackColor: Colors.blueAccent.withOpacity(0.2),
                      thumbColor: Colors.white,
                      overlayColor: Colors.blueAccent.withOpacity(0.2),
                      trackHeight: 6.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                    ),
                    child: Slider(
                      value: _currentRate,
                      min: 0.1,
                      max: 1.5,
                      divisions: 14,
                      onChanged: (value) {
                        setState(() {
                          _currentRate = value;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Çok Yavaş",
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Çok Hızlı",
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- SES TONU (PITCH) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Ses Tonu (Kalınlık)",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _currentPitch.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.purpleAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.purpleAccent,
                      inactiveTrackColor: Colors.purpleAccent.withOpacity(0.2),
                      thumbColor: Colors.white,
                      overlayColor: Colors.purpleAccent.withOpacity(0.2),
                      trackHeight: 6.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                    ),
                    child: Slider(
                      value: _currentPitch,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      onChanged: (value) {
                        setState(() {
                          _currentPitch = value;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Kalın Ses",
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "İnce Ses",
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- TEST ALANI ---
                  TextField(
                    controller: _testTextController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "İngilizce Test Metni",
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5),
                      ),
                      prefixIcon: const Icon(Icons.text_fields_rounded, color: Colors.blueAccent),
                      filled: true,
                      fillColor: const Color(0xFF1E293B).withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 35),

                  // --- BUTONLAR ---
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testVoice,
                          icon: const Icon(Icons.play_circle_fill_rounded),
                          label: const Text(
                            "Dinle",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.blueAccent.withOpacity(0.5), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            backgroundColor: Colors.blueAccent.withOpacity(0.1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveSettings,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text(
                            "Kaydet",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: Colors.purpleAccent,
                            elevation: 8,
                            shadowColor: Colors.purpleAccent.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
