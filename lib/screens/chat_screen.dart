import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ai_client.dart';
import '../services/chat_service.dart';
import 'tts_service.dart';
import '../services/subscription_service.dart';
import 'paywall_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final Map<String, dynamic>? correction;
  String? translation;
  bool isTranslating;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.correction,
    this.translation,
    this.isTranslating = false,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TtsService _ttsService = TtsService();
  final SubscriptionService _subService = SubscriptionService();
  int _currentUsage = 0;
  int _currentLimit = 3;
  bool _isUnlimited = false;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  final List<Map<String, Object?>> _history = [];

  bool _isLoading = false;
  bool _isStreaming = false;
  int _chatMsgCount = 0;
  String _userLevel = 'A1';

  String _selectedMode = 'Serbest';
  final List<String> _modes = [
    'Serbest',
    'Gramer',
    'Kelime',
    'Günlük',
    'İş',
    'Seyahat',
  ];

  @override
  void initState() {
    super.initState();
    _chatService.warmUp();
    _loadUserData();
    _loadLimits();

    // Add initial welcome message
    _messages.add(
      ChatMessage(
        text:
            "Hello! I am your AI English tutor. Let's start chatting in English!",
        isUser: false,
      ),
    );
  }

  Future<void> _loadLimits() async {
    final usage = await _subService.getActionUsage('chatMsgCount');
    if (mounted) {
      setState(() {
        _currentUsage = usage['current'] ?? 0;
        _currentLimit = usage['limit'] ?? 3;
        _isUnlimited = _currentLimit >= 999999;
      });
    }
  }

  Future<void> _loadUserData() async {
    // Kullanıcı belgesi SubscriptionService önbelleğinden gelir (ek okuma yok).
    final data = await _subService.getUserData();
    if (data.isNotEmpty && mounted) {
      setState(() {
        _chatMsgCount = data['dailyUsage']?['chatMsgCount'] ?? 0;
        _userLevel = data['level'] ?? 'A1';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Limit kontrolü önbellekten yapılır, ağ beklemesi yok.
    if (!await _subService.canChat()) {
      _showLimitDialog();
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
      _isStreaming = false;
    });

    _messageController.clear();
    _scrollToBottom();

    // Akış başlayınca yapay zeka balonu bu indekste güncellenir.
    int? aiIndex;

    try {
      final aiResponse = await _chatService.sendMessage(
        text,
        _selectedMode,
        _userLevel,
        _history,
        onPartial: (partial) {
          if (!mounted) return;
          setState(() {
            _isStreaming = true;
            final bubble = ChatMessage(text: partial, isUser: false);
            if (aiIndex == null) {
              _messages.add(bubble);
              aiIndex = _messages.length - 1;
            } else {
              _messages[aiIndex!] = bubble;
            }
          });
          _scrollToBottom();
        },
      );

      // Update history for Gemini
      _history.add(AiClient.userContent(text));
      _history.add(AiClient.modelContent(aiResponse['reply'] ?? ''));

      if (mounted) {
        setState(() {
          final finalMessage = ChatMessage(
            text: aiResponse['reply'] ?? '',
            isUser: false,
            correction: aiResponse['correction'],
          );
          if (aiIndex == null) {
            _messages.add(finalMessage);
          } else {
            _messages[aiIndex!] = finalMessage;
          }
          _isLoading = false;
          _isStreaming = false;
          if (!_isUnlimited) _currentUsage++;
        });
        _scrollToBottom();

        // Auto-play TTS (Optional, you can comment this out if user prefers manual play)
        // _ttsService.speak(aiResponse['reply'] ?? '');
      }

      // Sayaç ve geçmiş kaydı cevabı bekletmeden, paralel olarak arka planda.
      unawaited(_recordMessage(text, aiResponse));
    } catch (e) {
      if (mounted) {
        setState(() {
          if (aiIndex != null) _messages.removeAt(aiIndex!);
          _isLoading = false;
          _isStreaming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AiClient.userMessage(e)),
            backgroundColor: AppColors.dangerFill,
          ),
        );
      }
    }
  }

  Future<void> _recordMessage(String text, Map<String, dynamic> aiResponse) async {
    try {
      await Future.wait([
        _subService.incrementChat(),
        _chatService.saveMessageToHistory(_selectedMode, text, aiResponse),
      ]);
    } catch (e) {
      debugPrint("Chat kayıt hatası: $e");
    }
  }

  void _translateMessage(int index) async {
    if (_messages[index].translation != null ||
        _messages[index].isTranslating) {
      return;
    }
    setState(() {
      _messages[index].isTranslating = true;
    });

    final translation = await _chatService.translateText(_messages[index].text);

    if (mounted) {
      setState(() {
        _messages[index].translation = translation;
        _messages[index].isTranslating = false;
      });
      _scrollToBottom();
    }
  }

  void _showLimitDialog() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const PaywallScreen()));
  }

  void _changeMode(String val) {
    if (val == _selectedMode) return;
    setState(() {
      _selectedMode = val;
      _history.clear();
      _messages.clear();
      _messages.add(
        ChatMessage(
          text: "Mod '$val' olarak değiştirildi. Let's practice!",
          isUser: false,
        ),
      );
    });
  }

  static const List<String> _starters = [
    "Hi! How are you today?",
    "Can you help me practice for a job interview?",
    "Let's talk about my favorite movie.",
  ];

  void _sendStarter(String text) {
    _messageController.text = text;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgTop,
        titleSpacing: 0,
        centerTitle: false,
        title: Row(
          children: [
            const _AiAvatar(size: 38),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Octopus AI', style: AppText.heading(size: 17)),
                const Row(
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: AppColors.success),
                    SizedBox(width: 6),
                    Text('İngilizce öğretmenin', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: InfoPill(
              icon: Icons.chat_bubble_outline_rounded,
              label: _isUnlimited ? 'Sınırsız' : '$_currentUsage/$_currentLimit',
              color: AppColors.secondary,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _buildModeChips(),
        ),
      ),
      body: AppBackground(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                itemCount: _messages.length + (_isLoading && !_isStreaming ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _messages.length) return const _TypingBubble();
                  return _buildMessageBubble(index);
                },
              ),
            ),
            if (_messages.length == 1 && !_isLoading) _buildStarters(),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChips() {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: AppColors.bgTop,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 9),
        itemCount: _modes.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final mode = _modes[i];
          final selected = mode == _selectedMode;
          return GestureDetector(
            onTap: () => _changeMode(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: selected ? AppColors.primary : AppColors.border),
              ),
              child: Text(
                mode,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStarters() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: _starters.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) => ActionChip(
          label: Text(_starters[i]),
          labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          avatar: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primaryLight),
          onPressed: () => _sendStarter(_starters[i]),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(int index) {
    final message = _messages[index];
    final bool hasCorrection = message.correction != null &&
        message.correction!['original'] != null &&
        message.correction!['original'].toString().isNotEmpty;
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppRadius.lg),
              topRight: Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(AppRadius.lg),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(
            message.text,
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AiAvatar(size: 30),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(AppRadius.lg),
                        bottomLeft: Radius.circular(AppRadius.lg),
                        bottomRight: Radius.circular(AppRadius.lg),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.45),
                        ),
                        if (message.isTranslating)
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        if (message.translation != null) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(),
                          ),
                          Text(
                            message.translation!,
                            style: const TextStyle(color: AppColors.secondary, fontSize: 14, height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BubbleAction(
                        icon: Icons.volume_up_rounded,
                        label: 'Dinle',
                        onTap: () => _ttsService.speak(message.text),
                      ),
                      _BubbleAction(
                        icon: Icons.translate_rounded,
                        label: 'Çevir',
                        onTap: () => _translateMessage(index),
                      ),
                    ],
                  ),
                  if (hasCorrection) _buildCorrection(message.correction!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrection(Map<String, dynamic> correction) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_fix_high_rounded, color: AppColors.secondary, size: 16),
              SizedBox(width: 6),
              Text(
                "GRAMER DÜZELTMESİ",
                style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _correctionLine(Icons.close_rounded, AppColors.danger, "${correction['original']}", strike: true),
          const SizedBox(height: 6),
          _correctionLine(Icons.check_rounded, AppColors.success, "${correction['corrected']}"),
          if ((correction['explanation'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              correction['explanation'].toString(),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _correctionLine(IconData icon, Color color, String text, {bool strike = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 1),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: strike ? AppColors.textMuted : AppColors.textPrimary,
              decoration: strike ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.danger,
              fontSize: 14,
              fontWeight: strike ? FontWeight.w500 : FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.bgBottom,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "İngilizce bir şeyler yazın...",
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.surfaceHigh,
                ),
                icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                onPressed: _isLoading ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiAvatar extends StatelessWidget {
  const _AiAvatar({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: Image.asset('assets/logo_transparent.png'),
    );
  }
}

class _BubbleAction extends StatelessWidget {
  const _BubbleAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Yapay zeka cevap hazırlarken gösterilen "yazıyor..." balonu.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const _AiAvatar(size: 30),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(AppRadius.lg),
                bottomRight: Radius.circular(AppRadius.lg),
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final t = (_controller.value - i * 0.18) % 1.0;
                  final lift = t < 0.4 ? (t < 0.2 ? t / 0.2 : (0.4 - t) / 0.2) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Transform.translate(
                      offset: Offset(0, -4 * lift),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.5 + 0.5 * lift),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
