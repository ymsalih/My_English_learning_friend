import 'package:flutter/widgets.dart';

/// [StreamBuilder] ile aynı, ancak stream'i her yeniden çizimde değil yalnızca
/// [queryKey] değiştiğinde oluşturur.
///
/// Firestore sorgusunu build içinde `query.snapshots()` olarak yazmak, ekran
/// her yeniden çizildiğinde (setState, tema değişimi, klavye açılması...)
/// dinleyicinin kapatılıp yeniden açılmasına yol açar. Bu bileşen dinleyiciyi
/// sorgunun parametreleri (anahtar) değişene kadar korur.
class CachedStreamBuilder<T> extends StatefulWidget {
  const CachedStreamBuilder({
    super.key,
    required this.queryKey,
    required this.create,
    required this.builder,
  });

  /// Sorgunun parametreleri; değişince stream yeniden oluşturulur.
  /// Birden çok değer için kayıt kullanılabilir: `(uid, limit)`.
  final Object? queryKey;
  final Stream<T> Function() create;
  final AsyncWidgetBuilder<T> builder;

  @override
  State<CachedStreamBuilder<T>> createState() => _CachedStreamBuilderState<T>();
}

class _CachedStreamBuilderState<T> extends State<CachedStreamBuilder<T>> {
  late Stream<T> _stream = widget.create();

  @override
  void didUpdateWidget(covariant CachedStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queryKey != widget.queryKey) {
      _stream = widget.create();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(stream: _stream, builder: widget.builder);
}
