import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart'; // Global cameras listesini çekiyoruz

class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({super.key});

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer();

  bool _isProcessing = false; // Fotoğraf işlenirken loading göstermek için
  String _scannedText = ""; // Okunan metin sonucu
  bool _isFlashOn = false; // Fener durumu

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // 📸 KAMERA BAŞLATMA
  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) {
      debugPrint("Kamera listesi boş!");
      return;
    }

    // Arka kamerayı bul
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    // Çözünürlüğü 'high' tutuyoruz (Flaşın çökmemesi için en stabil seviye)
    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint("Kamera başlatılamadı: $e");
    }
  }

  // 🔦 FLAŞ KONTROLÜ (Torch modu)
  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
        setState(() => _isFlashOn = false);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
        setState(() => _isFlashOn = true);
      }
    } catch (e) {
      debugPrint("Flaş hatası: $e");
      setState(() => _isFlashOn = false);
    }
  }

  // 📸 FOTOĞRAF ÇEK VE METNİ TARA (Profesyonel Snapshot Yöntemi)
  Future<void> _takePictureAndProcess() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _scannedText = "";
    });

    try {
      await _cameraController!.setFocusMode(FocusMode.auto);
      final XFile picture = await _cameraController!.takePicture();
      await _processImageFile(picture.path);
    } catch (e) {
      debugPrint("OCR Hatası: $e");
      setState(() => _scannedText = "Hata oluştu.");
      setState(() => _isProcessing = false);
    }
  }

  // 🖼️ GALERİDEN SEÇ VE METNİ TARA
  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _isProcessing = true;
          _scannedText = "";
        });
        await _processImageFile(image.path);
      }
    } catch (e) {
      debugPrint("Galeri Hatası: $e");
    }
  }

  // Ortak OCR İşleme Fonksiyonu
  Future<void> _processImageFile(String path) async {
    try {
      final inputImage = InputImage.fromFilePath(path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.trim().isNotEmpty) {
        // Artık sadece ilk kelimeyi değil, TÜM metni alıyoruz
        setState(() {
          _scannedText = recognizedText.text.trim();
        });
      } else {
        setState(() => _scannedText = "Metin tespit edilemedi.");
      }
    } catch (e) {
      debugPrint("OCR İşleme Hatası: $e");
      setState(() => _scannedText = "Hata oluştu.");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.tealAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. KAMERA ÖNİZLEME
          CameraPreview(_cameraController!),

          // 2. VİZÖR (ODAK KUTUSU) VE KARARTMA
          // VİZÖR KALDIRILDI (Tam sayfa tarama desteklendiği için)

          // 3. ÜST BAR (GERİ VE FLAŞ)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                IconButton(
                  icon: Icon(
                    _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: _isFlashOn ? Colors.yellowAccent : Colors.white,
                    size: 30,
                  ),
                  onPressed: _toggleFlash,
                ),
              ],
            ),
          ),

          // 4. ALT PANEL (SONUÇ VE BUTONLAR)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isProcessing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(color: Colors.teal),
                    )
                  else if (_scannedText.isEmpty ||
                      _scannedText == "Metin tespit edilemedi.")
                    Column(
                      children: [
                        Text(
                          _scannedText.isEmpty
                              ? "Metni ekrana hizalayın veya Galeriden seçin"
                              : _scannedText,
                          style: TextStyle(
                            color: _scannedText.isEmpty ? Colors.grey : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _pickImageFromGallery,
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.purple.shade50,
                                child: const Icon(
                                  Icons.photo_library,
                                  color: Colors.purple,
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(width: 30),
                            GestureDetector(
                              onTap: _takePictureAndProcess,
                              child: CircleAvatar(
                                radius: 35,
                                backgroundColor: Colors.teal.shade50,
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.teal,
                                  size: 35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        const Text(
                          "Tespit Edilen Metin:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Text(
                              _scannedText,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    setState(() => _scannedText = ""),
                                child: const Text("İptal"),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(context, _scannedText),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                ),
                                child: const Text(
                                  "Çevir",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
