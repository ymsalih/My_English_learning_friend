import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../services/app_feedback.dart';

/// Uygulamanın tamamında, gerçekten tıklanabilir bir öğeye (buton, kart, liste
/// öğesi, sekme...) yapılan kısa dokunuşlarda [AppFeedback.tap] çağırır.
///
/// Tek bir noktadan çalıştığı için yüzlerce butona tek tek eklemek gerekmez.
///
/// Performans: parmak hareketlerini hiç işlemez (kaydırmada maliyet sıfır);
/// yalnızca "parmak indi" ve "parmak kalktı" anlarına bakar. Gerçek bir
/// dokunuşta tek bir hızlı sınama (hit test) yapılır.
///
/// Ses çıkmayanlar: kaydırma/sürükleme, uzun basma, boş alan, devre dışı
/// butonlar ve yazı alanları.
class TapFeedbackScope extends StatefulWidget {
  const TapFeedbackScope({super.key, required this.child, this.onTap});

  final Widget child;

  /// Varsayılan [AppFeedback.tap]; testlerde değiştirilebilir.
  final VoidCallback? onTap;

  @override
  State<TapFeedbackScope> createState() => _TapFeedbackScopeState();
}

class _TapFeedbackScopeState extends State<TapFeedbackScope> {
  static const Duration _maxTapDuration = Duration(milliseconds: 350);

  int? _pointer;
  Offset _downPosition = Offset.zero;
  Duration _downTime = Duration.zero;

  void _onDown(PointerDownEvent event) {
    // Yalnızca ilk parmak izlenir (çok parmaklı hareketler dokunuş sayılmaz).
    if (_pointer != null) {
      _pointer = -1;
      return;
    }
    _pointer = event.pointer;
    _downPosition = event.position;
    _downTime = event.timeStamp;
  }

  void _onUp(PointerUpEvent event) {
    if (_pointer != event.pointer) {
      if (_pointer == -1) _pointer = null;
      return;
    }
    _pointer = null;

    final moved = (event.position - _downPosition).distance;
    if (moved > kTouchSlop || event.timeStamp - _downTime > _maxTapDuration) return;
    if (_hitsTappable(event.position)) (widget.onTap ?? AppFeedback.tap)();
  }

  void _onCancel(PointerCancelEvent event) {
    if (_pointer == event.pointer || _pointer == -1) _pointer = null;
  }

  bool _hitsTappable(Offset position) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, position, View.of(context).viewId);
    var tappable = false;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderEditable) return false; // yazı alanı: tıklama sesi yok
      // GestureDetector dokunuşunu RenderSemanticsGestureHandler'da, InkWell
      // (ve onun üzerine kurulu tüm Material butonlar, kartlar, liste öğeleri)
      // ise kendi Semantics düğümünde bildirir. İkisi de aranır.
      if (target is RenderSemanticsGestureHandler && target.onTap != null) {
        tappable = true;
      } else if (target is RenderSemanticsAnnotations && target.properties.onTap != null) {
        tappable = true;
      }
    }
    return tappable;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: widget.child,
    );
  }
}
