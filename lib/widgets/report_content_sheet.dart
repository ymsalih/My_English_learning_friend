import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Yapay zekanın ürettiği bir cevabı/hikayeyi bildirmek için alt sayfa.
/// Bildirimler `content_reports` koleksiyonuna yazılır (yalnızca oluşturulabilir).
Future<void> showReportContentSheet(
  BuildContext context, {
  required String source,
  required String content,
  String? userContext,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportSheet(source: source, content: content, userContext: userContext),
  );
}

const _reasons = <String, String>{
  'inappropriate': 'Uygunsuz veya zararlı içerik',
  'hateful': 'Nefret, taciz veya ayrımcılık',
  'wrong': 'Yanlış veya yanıltıcı bilgi',
  'other': 'Diğer',
};

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.source, required this.content, this.userContext});

  final String source;
  final String content;
  final String? userContext;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String _reason = 'inappropriate';
  bool _sending = false;
  // "Diğer" seçilince kullanıcının yazdığı açıklama (zorunlu).
  final _noteController = TextEditingController();

  bool get _needsNote => _reason == 'other';
  bool get _canSubmit => !_sending && (!_needsNote || _noteController.text.trim().isNotEmpty);

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _clip(String text, int max) => text.length <= max ? text : text.substring(0, max);

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !_canSubmit) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await FirebaseFirestore.instance.collection('content_reports').add({
        'uid': user.uid,
        'source': widget.source,
        'reason': _reason,
        'content': _clip(widget.content, 2000),
        'userContext': _clip(widget.userContext ?? '', 1000),
        'createdAt': FieldValue.serverTimestamp(),
        if (_needsNote) 'note': _clip(_noteController.text.trim(), 500),
      }).timeout(const Duration(seconds: 10));
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Bildirimin alındı. Teşekkürler, inceleyeceğiz.'),
          backgroundColor: AppColors.successFill,
        ),
      );
    } catch (e) {
      debugPrint('Report error: $e');
      if (mounted) setState(() => _sending = false);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Bildirim gönderilemedi. Lütfen tekrar deneyin.'),
          backgroundColor: AppColors.dangerFill,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Klavye açılınca kutu ve buton klavyenin üstünde kalır; küçük ekranlarda
    // taşmaması için sayfa kaydırılabilir.
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + media.viewPadding.bottom + media.viewInsets.bottom),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('İçeriği bildir', style: AppText.heading(size: 20)),
            const SizedBox(height: 6),
            Text(
              'Bu içerik yapay zeka tarafından üretildi. Sorun olduğunu düşünüyorsan nedenini seç.',
              style: AppText.caption,
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v ?? _reason),
              child: Column(
                children: [
                  for (final entry in _reasons.entries)
                    RadioListTile<String>(
                      enableFeedback: false,
                      contentPadding: EdgeInsets.zero,
                      value: entry.key,
                      title: Text(entry.value, style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                    ),
                ],
              ),
            ),
            if (_needsNote) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _noteController,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Sorunu kısaca açıkla'),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSubmit ? _submit : null,
                child: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Bildir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
