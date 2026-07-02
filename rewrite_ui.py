import re
import sys

def main():
    try:
        with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
            content = f.read()

        # Find the start of the build method
        build_start = content.find('  @override\n  Widget build(BuildContext context) {')
        if build_start == -1:
            print("Could not find build method")
            sys.exit(1)

        # Find the end of the UI helper methods (before _buildPremiumDrawer)
        drawer_start = content.find('  Widget _buildPremiumDrawer(User? user) {')
        if drawer_start == -1:
            print("Could not find drawer method")
            sys.exit(1)

        new_ui = r'''  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: _buildPremiumDrawer(user),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const Text(
          'Owlish',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2),
        ),
        actions: [
          if (_streak > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent),
                  const SizedBox(width: 4),
                  Text('$_streak', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Premium Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Animated Aura circles
          Positioned(top: -50, left: -50, child: _buildAura(Colors.purpleAccent.withOpacity(0.3), 300)),
          Positioned(top: 200, right: -100, child: _buildAura(Colors.blueAccent.withOpacity(0.2), 400)),
          
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Merhaba, $_userName \ud83d\udc4b", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
                        const SizedBox(height: 5),
                        Text("Öğrenme serüvenine nereden devam edelim?", style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.7))),
                        const SizedBox(height: 30),

                        _buildPremiumStatCard(context),
                        
                        const SizedBox(height: 40),
                        const Text("Ana Modüller", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 15),

                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.9,
                          children: [
                            _buildGlassCard(context, 'Kelime Havuzu', 'Sözlüğün', Icons.auto_awesome_motion, Colors.blueAccent, const HomeScreen()),
                            _buildGlassCard(context, 'Kendini Test Et', 'Bilgini Sına', Icons.psychology, Colors.purpleAccent, const TestScreen()),
                            _buildGlassCard(context, 'Hikaye Oku', 'Etkileşimli', Icons.auto_stories, Colors.pinkAccent, const StoryScreen()),
                            _buildGlassCard(context, 'Yapay Zeka', 'Sohbet Et', Icons.forum, Colors.tealAccent, const ChatScreen()),
                          ],
                        ),

                        const SizedBox(height: 30),
                        const Text("Pratik & Araçlar", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 15),

                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.1,
                          children: [
                            _buildGlassCard(context, 'Çeviri', 'Akıllı', Icons.g_translate, Colors.greenAccent, const TranslationScreen()),
                            _buildGlassCard(context, 'Öğrendiklerim', 'Arşiv', Icons.workspace_premium, Colors.amberAccent, const LearnedWordsScreen()),
                            _buildGlassCard(context, 'Paketler', 'Hazır Setler', Icons.inventory_2, Colors.orangeAccent, const WordLearningScreen()),
                            _buildGlassCard(context, 'Haberler', 'Güncel Okuma', Icons.menu_book, Colors.cyanAccent, const NewsScreen()),
                            _buildGlassCard(context, 'Video', 'İzleyerek Öğren', Icons.play_circle_fill, Colors.redAccent, const VideoPracticeScreen()),
                          ],
                        ),
                        const SizedBox(height: 60),
                      ],
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

  Widget _buildAura(Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildPremiumStatCard(BuildContext context) {
    int totalAnswered = _totalCorrect + _totalWrong;
    double successRate = totalAnswered > 0 ? (_totalCorrect / totalAnswered) : 0.0;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProgressReportScreen())),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("GENEL DURUM", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      const SizedBox(height: 8),
                      Text(totalAnswered > 0 ? "Harika İlerliyorsun!" : "Hemen Başlayalım!", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (totalAnswered > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 16),
                              const SizedBox(width: 6),
                              Text(str(_totalLearned) + " kelime tamamlandı", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                    ],
                  ),
                ),
                if (totalAnswered > 0)
                  SizedBox(
                    width: 70, height: 70,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: successRate, strokeWidth: 8,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(successRate > 0.7 ? Colors.greenAccent : Colors.amberAccent),
                        ),
                        Center(child: Text("%" + str(int(successRate * 100)), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                      ],
                    ),
                  )
                else
                  const Icon(Icons.rocket_launch, color: Colors.white, size: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard(BuildContext context, String title, String subtitle, IconData icon, Color iconColor, Widget destination) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: iconColor.withOpacity(0.2), shape: BoxShape.circle),
                    child: Icon(icon, color: iconColor, size: 28),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

'''
        # Fix Python string interpolation issues with Dart by un-escaping or properly escaping variables:
        new_ui = new_ui.replace("str(_totalLearned)", "'$_totalLearned'")
        new_ui = new_ui.replace("str(int(successRate * 100))", "'${(successRate * 100).toInt()}'")

        final_content = content[:build_start] + new_ui + content[drawer_start:]

        with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
            f.write(final_content)
        print("Successfully updated dashboard_screen.dart")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
