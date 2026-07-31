import 'package:flutter/material.dart';
import 'auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Kendi Sözlüğünüzü Yaratın',
      'subtitle': 'Bilmediğiniz kelimeleri havuza atın, yapay zeka sizin için anında çevirsin ve hafızanıza kazısın.',
      'icon': Icons.auto_awesome_motion_rounded,
      'color': Colors.blueAccent,
    },
    {
      'title': 'Sınırsız Pratik Yapın',
      'subtitle': 'Öğrendiğiniz kelimelerle kendinizi test edin, akıllı AI öğretmenimizle birebir İngilizce konuşun.',
      'icon': Icons.forum_rounded,
      'color': Colors.indigoAccent,
    },
    {
      'title': 'Maceranızı Siz Çizin',
      'subtitle': 'Sadece okumayın, yaşayın! Kendi etkileşimli hikayelerinizin kahramanı olarak İngilizce öğrenin.',
      'icon': Icons.auto_stories_rounded,
      'color': Colors.deepPurpleAccent,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) => const AuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Arka plan animasyonlu gradient hissi
          Positioned(
            top: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pages[_currentPage]['color'].withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pages[(_currentPage + 1) % _pages.length]['color'].withOpacity(0.1),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Top Bar (Skip Button)
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _goToLogin,
                    child: const Text('Atla', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                // PageView
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (int page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _pages[index]['color'].withOpacity(0.1),
                              ),
                              child: Icon(
                                _pages[index]['icon'],
                                size: 100,
                                color: _pages[index]['color'],
                              ),
                            ),
                            const SizedBox(height: 60),
                            Text(
                              _pages[index]['title'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _pages[index]['subtitle'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF64748B),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Indicator & Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40),
                  child: Column(
                    children: [
                      // Dots Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 10,
                            width: _currentPage == index ? 30 : 10,
                            decoration: BoxDecoration(
                              color: _currentPage == index ? _pages[_currentPage]['color'] : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Buttons
                      ElevatedButton(
                        onPressed: _goToLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shadowColor: Colors.deepPurple.withOpacity(0.5),
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Hemen Başla', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 15),
                      OutlinedButton(
                        onPressed: _goToLogin,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                          minimumSize: const Size(double.infinity, 60),
                          side: BorderSide(color: Colors.deepPurple.shade200, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Zaten Hesabım Var', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ],
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
