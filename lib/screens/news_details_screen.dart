import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Web kontrolü için
import 'package:url_launcher/url_launcher.dart'; // Yeni sekmede açmak için

class NewsDetailsScreen extends StatefulWidget {
  final String url;
  final String title;

  const NewsDetailsScreen({super.key, required this.url, required this.title});

  @override
  State<NewsDetailsScreen> createState() => _NewsDetailsScreenState();
}

class _NewsDetailsScreenState extends State<NewsDetailsScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    // Web'de donmayı önlemek için sadece mobilde başlatıyoruz
    if (!kIsWeb) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() => _isLoading = true);
            },
            onPageFinished: (String url) {
              setState(() => _isLoading = false);
            },
            onWebResourceError: (error) {
              setState(() => _hasError = true);
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _launchInBrowser() async {
    final Uri url = Uri.parse(widget.url);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Bağlantı açılamadı.")));
      }
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      _controller.loadRequest(Uri.parse('about:blank'));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded, color: Colors.teal),
            onPressed: _launchInBrowser,
          ),
        ],
      ),
      body: kIsWeb
          ? _buildWebFallback()
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  ),
                if (_hasError) _buildWebFallback(),
              ],
            ),
    );
  }

  Widget _buildWebFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🚀 Buradaki 'const' ibaresini kaldırdık çünkü withOpacity sabit değildir.
            Icon(
              Icons.language_rounded,
              size: 80,
              color: Colors.teal.withOpacity(0.2),
            ),
            const SizedBox(height: 20),
            // 🚀 Buradaki 'const' ibaresini de kaldırarak hata riskini sıfırladık.
            Text(
              "Haber Detayları",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00695C),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Tarayıcı güvenlik kısıtlamaları nedeniyle haberleri yeni bir sekmede açarak daha rahat okuyabilirsiniz.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 15),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _launchInBrowser,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text("Haberi Oku"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
