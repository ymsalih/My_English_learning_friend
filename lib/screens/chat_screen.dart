import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../services/chat_service.dart';
import 'tts_service.dart';
import '../services/subscription_service.dart';
import 'paywall_screen.dart';

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
  final List<Content> _history = [];

  bool _isLoading = false;
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
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _chatMsgCount = doc.data()?['dailyUsage']?['chatMsgCount'] ?? 0;
          _userLevel = doc.data()?['level'] ?? 'A1';
        });
      }
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
    if (text.isEmpty) return;

    if (!await _subService.canChat()) {
      _showLimitDialog();
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final aiResponse = await _chatService.sendMessage(
        text,
        _selectedMode,
        _userLevel,
        _history,
      );

      // Update history for Gemini
      _history.add(Content.text(text));
      _history.add(Content.model([TextPart(aiResponse['reply'] ?? '')]));

      // Update daily limit in Firestore and reload limits UI
      await _subService.incrementChat();
      await _loadLimits();

      // Save to Firestore
      await _chatService.saveMessageToHistory(_selectedMode, text, aiResponse);

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: aiResponse['reply'] ?? '',
              isUser: false,
              correction: aiResponse['correction'],
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();

        // Auto-play TTS (Optional, you can comment this out if user prefers manual play)
        // _ttsService.speak(aiResponse['reply'] ?? '');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMessage = e.toString();
        if (errorMessage.contains('503') || errorMessage.contains('UNAVAILABLE')) {
          errorMessage = 'Yapay zeka sunucuları şu an çok yoğun. Lütfen birkaç dakika sonra tekrar deneyin.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'OwlishAI',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withAlpha(25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: Colors.cyanAccent, size: 24),
                const SizedBox(width: 8),
                const Text(
                  "Mod:",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedMode,
                      dropdownColor: const Color(0xFF1E293B),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
                      items: _modes.map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(
                            mode,
                            style: const TextStyle(fontSize: 15, color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
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
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.pinkAccent.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.pinkAccent.withAlpha(100)),
              ),
              margin: const EdgeInsets.only(right: 16),
              child: Text(
                _isUnlimited ? 'Sınırsız' : '$_currentUsage/$_currentLimit',
                style: const TextStyle(
                  color: Colors.pinkAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(index);
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(int index) {
    final message = _messages[index];
    bool hasCorrection =
        message.correction != null &&
        message.correction!['original'] != null &&
        message.correction!['original'].toString().isNotEmpty;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          crossAxisAlignment: message.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!message.isUser)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.volume_up,
                          size: 20,
                          color: Colors.cyanAccent,
                        ),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        onPressed: () => _ttsService.speak(message.text),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.g_translate,
                          size: 20,
                          color: Colors.cyanAccent,
                        ),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        onPressed: () => _translateMessage(index),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: message.isUser
                          ? const LinearGradient(
                              colors: [Colors.purpleAccent, Colors.deepPurpleAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: message.isUser ? null : Colors.white.withAlpha(20),
                      border: message.isUser ? null : Border.all(color: Colors.white.withAlpha(30)),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: message.isUser
                            ? const Radius.circular(20)
                            : const Radius.circular(4),
                        bottomRight: message.isUser
                            ? const Radius.circular(4)
                            : const Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: message.isUser ? Colors.purpleAccent.withAlpha(50) : Colors.black.withAlpha(20),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: message.isUser ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                        if (message.isTranslating)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                            ),
                          ),
                        if (message.translation != null) ...[
                          const SizedBox(height: 8),
                          Divider(color: Colors.white.withAlpha(50)),
                          Text(
                            message.translation!,
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (hasCorrection)
              Container(
                margin: const EdgeInsets.only(top: 6, left: 40),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withAlpha(80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.amberAccent,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Gramer Düzeltmesi",
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Yanlış: ${message.correction!['original']}",
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      "Doğru: ${message.correction!['corrected']}",
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.correction!['explanation'],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Colors.white.withAlpha(20))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withAlpha(30)),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "İngilizce bir şeyler yazın...",
                    hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Colors.cyanAccent, Colors.blueAccent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withAlpha(100),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Color(0xFF0F172A)),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
