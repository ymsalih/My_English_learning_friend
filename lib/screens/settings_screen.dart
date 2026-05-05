import 'package:flutter/material.dart';
import 'tts_service.dart'; // 🚀 Merkezi ses servisimizi çağırıyoruz

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TtsService _ttsService = TtsService();

  double _currentRate = 0.55;
  double _currentPitch = 1.0;

  final TextEditingController _testTextController = TextEditingController(
    text: "Hello, this is a test for the new voice settings.",
  );

  @override
  void initState() {
    super.initState();
    // Ekran açıldığında servisteki mevcut ayarları alıyoruz
    _currentRate = _ttsService.speechRate;
    _currentPitch = _ttsService.pitch;
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text("Ses ayarları başarıyla kaydedildi! ✨"),
            ],
          ),
          backgroundColor: Colors.green.shade600,
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
      appBar: AppBar(
        title: const Text(
          'Ses Ayarları',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueGrey.shade800, Colors.blueGrey.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueGrey.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- BİLGİ KARTI ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueGrey.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.record_voice_over_rounded,
                      size: 40,
                      color: Colors.blueGrey.shade700,
                    ),
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Text(
                        "Burada yaptığınız değişiklikler tüm uygulamadaki (Test, Çeviri, Havuz) okuma hızını ve tonunu anında günceller.",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // --- SES HIZI (RATE) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Okuma Hızı",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade900,
                    ),
                  ),
                  Text(
                    _currentRate.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.blueAccent,
                  inactiveTrackColor: Colors.blueAccent.withOpacity(0.2),
                  thumbColor: Colors.blueAccent,
                  overlayColor: Colors.blueAccent.withOpacity(0.2),
                  trackHeight: 8.0,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12.0,
                  ),
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
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Çok Yavaş",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Çok Hızlı",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // --- SES TONU (PITCH) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Ses Tonu (İncelik/Kalınlık)",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade900,
                    ),
                  ),
                  Text(
                    _currentPitch.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurpleAccent.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.deepPurpleAccent,
                  inactiveTrackColor: Colors.deepPurpleAccent.withOpacity(0.2),
                  thumbColor: Colors.deepPurpleAccent,
                  overlayColor: Colors.deepPurpleAccent.withOpacity(0.2),
                  trackHeight: 8.0,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12.0,
                  ),
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
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Kalın Ses",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "İnce Ses",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // --- TEST ALANI ---
              TextField(
                controller: _testTextController,
                decoration: InputDecoration(
                  labelText: "İngilizce Test Metni",
                  labelStyle: TextStyle(color: Colors.blueGrey.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                      color: Colors.blueAccent,
                      width: 2,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.text_fields,
                    color: Colors.blueGrey.shade400,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 25),

              // --- BUTONLAR ---
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testVoice,
                      icon: const Icon(Icons.play_circle_fill),
                      label: const Text(
                        "Dinle",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.blueGrey.shade800,
                        side: BorderSide(
                          color: Colors.blueGrey.shade400,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save),
                      label: const Text(
                        "Kaydet",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green.shade600,
                        elevation: 5,
                        shadowColor: Colors.green.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
