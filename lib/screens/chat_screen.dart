import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../services/chat_service.dart';
import 'tts_service.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  final List<Content> _history = [];

  bool _isLoading = false;
  bool _isPro = false;
  String _userLevel = 'A1';
  int _dailyMessages = 0;
  String _lastMessageDate = '';

  String _selectedMode = 'Serbest';
  final List<String> _modes = ['Serbest', 'Gramer', 'Kelime', 'Günlük', 'İş', 'Seyahat'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDailyLimits();
    
    // Add initial welcome message
    _messages.add(
      ChatMessage(
        text: "Hello! I am your AI English tutor. Let's start chatting in English!",
        isUser: false,
      )
    );
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _isPro = doc.data()?['isPro'] ?? false;
          _userLevel = doc.data()?['level'] ?? 'A1';
        });
      }
    }
  }

  Future<void> _loadDailyLimits() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    final savedDate = prefs.getString('chat_last_date') ?? '';
    if (savedDate != today) {
      // New day, reset counter
      await prefs.setInt('chat_daily_messages', 0);
      await prefs.setString('chat_last_date', today);
      if (mounted) {
        setState(() {
        _dailyMessages = 0;
        _lastMessageDate = today;
      });
      }
    } else {
      if (mounted) {
        setState(() {
        _dailyMessages = prefs.getInt('chat_daily_messages') ?? 0;
        _lastMessageDate = today;
      });
      }
    }
  }

  Future<void> _incrementDailyLimit() async {
    final prefs = await SharedPreferences.getInstance();
    _dailyMessages++;
    await prefs.setInt('chat_daily_messages', _dailyMessages);
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

    if (!_isPro && _dailyMessages >= 3) {
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
      final aiResponse = await _chatService.sendMessage(text, _selectedMode, _userLevel, _history);
      
      // Update history for Gemini
      _history.add(Content.text(text));
      _history.add(Content.model([TextPart(aiResponse['reply'] ?? '')]));
      
      // Update daily limit
      if (!_isPro) {
        await _incrementDailyLimit();
      }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _translateMessage(int index) async {
    if (_messages[index].translation != null || _messages[index].isTranslating) {
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Günlük Limit Doldu"),
        content: const Text(
          "Ücretsiz planda günde sadece 3 AI mesajı atabilirsiniz. Sınırsız sohbet ve analizler için Premium'a geçebilirsiniz.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Anladım"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Odeme (Pricing) sayfasina yonlendir
            },
            child: const Text("Premium'a Geç"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Sohbet',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade800, Colors.blueAccent.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.mode_comment, color: Colors.indigo, size: 20),
                const SizedBox(width: 8),
                const Text("Mod:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedMode,
                      items: _modes.map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(mode, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedMode = val;
                            // Clear history when mode changes
                            _history.clear();
                            _messages.clear();
                            _messages.add(
                              ChatMessage(
                                text: "Mod '$val' olarak değiştirildi. Hadi başlayalım!",
                                isUser: false,
                              )
                            );
                          });
                        }
                      },
                    ),
                  ),
                ),
                if (!_isPro)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "$_dailyMessages/3",
                      style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.grey.shade100,
      body: Column(
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
              child: CircularProgressIndicator(),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(int index) {
    final message = _messages[index];
    bool hasCorrection = message.correction != null && 
                         message.correction!['original'] != null && 
                         message.correction!['original'].toString().isNotEmpty;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: Column(
          crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                        icon: const Icon(Icons.volume_up, size: 20, color: Colors.indigo),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        onPressed: () => _ttsService.speak(message.text),
                      ),
                      IconButton(
                        icon: const Icon(Icons.g_translate, size: 20, color: Colors.indigo),
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
                      color: message.isUser ? Colors.indigo.shade600 : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: message.isUser ? const Radius.circular(16) : const Radius.circular(4),
                        bottomRight: message.isUser ? const Radius.circular(4) : const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style: TextStyle(
                            color: message.isUser ? Colors.white : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                        if (message.isTranslating)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: SizedBox(
                              width: 15, height: 15, 
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        if (message.translation != null) ...[
                          const SizedBox(height: 8),
                          Divider(color: message.isUser ? Colors.white54 : Colors.black26),
                          Text(
                            message.translation!,
                            style: TextStyle(
                              color: message.isUser ? Colors.white70 : Colors.black54,
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
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "Gramer Düzeltmesi",
                          style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Yanlış: ${message.correction!['original']}",
                      style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.redAccent, fontSize: 13),
                    ),
                    Text(
                      "Doğru: ${message.correction!['corrected']}",
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.correction!['explanation'],
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontStyle: FontStyle.italic),
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
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: "İngilizce bir şeyler yazın...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.indigo, Colors.blueAccent],
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
