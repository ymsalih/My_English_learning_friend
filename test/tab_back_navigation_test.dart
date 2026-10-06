import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// DashboardScreen'deki geri tuşu kuralının modeli: Ana Sayfa dışındaki bir
/// sekmede geri tuşu Ana Sayfa'ya döner; açık yan menüyü önce kapatır; yalnızca
/// Ana Sayfa'dayken uygulamadan çıkılmasına izin verir.
class _TabsModel extends StatefulWidget {
  const _TabsModel();
  @override
  State<_TabsModel> createState() => _TabsModelState();
}

class _TabsModelState extends State<_TabsModel> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int tab = 0;

  /// Yarım kalmış test var mı (TestScreen.inProgress modeli).
  bool inProgress = false;

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Testten çıkılsın mı?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Devam et')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Çık')),
        ],
      ),
    );
    if (leave == true) inProgress = false;
    return leave == true;
  }

  Future<void> selectTab(int index) async {
    if (tab == 2 && index != 2 && inProgress) {
      if (!await _confirmLeave() || !mounted) return;
    }
    setState(() => tab = index);
  }

  void _onBack(bool didPop, Object? result) {
    if (didPop) return;
    final scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
      return;
    }
    selectTab(0);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: _onBack,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const Drawer(child: Text('menü')),
        body: Center(child: Text('sekme $tab')),
        bottomNavigationBar: Row(children: [
          for (var i = 0; i < 3; i++) TextButton(onPressed: () => selectTab(i), child: Text('git$i')),
        ]),
      ),
    );
  }
}

void main() {
  Future<void> setup(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: _TabsModel()));
  }

  testWidgets('Ana Sayfa dışındaki sekmede geri tuşu Ana Sayfa\'ya döner', (tester) async {
    await setup(tester);
    await tester.tap(find.text('git2'));
    await tester.pump();
    expect(find.text('sekme 2'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pump();
    expect(handled, isTrue, reason: 'uygulama kapanmamalı');
    expect(find.text('sekme 0'), findsOneWidget, reason: 'Ana Sayfa sekmesine dönmeli');
  });

  testWidgets('Ana Sayfa\'dayken geri tuşu uygulamadan çıkışa izin verir', (tester) async {
    await setup(tester);
    final handled = await tester.binding.handlePopRoute();
    expect(handled, isFalse, reason: 'sistem uygulamayı kapatabilmeli');
  });

  testWidgets('yan menü açıkken geri tuşu önce menüyü kapatır', (tester) async {
    await setup(tester);
    await tester.tap(find.text('git1'));
    await tester.pump();
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffold.openDrawer();
    await tester.pumpAndSettle();
    expect(scaffold.isDrawerOpen, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(scaffold.isDrawerOpen, isFalse, reason: 'menü kapanmalı');
    expect(find.text('sekme 1'), findsOneWidget, reason: 'sekme değişmemeli');

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('sekme 0'), findsOneWidget, reason: 'ikinci geri Ana Sayfa\'ya döner');
  });

  testWidgets('Ana Sayfa\'da yan menü açıkken geri tuşu yalnızca menüyü kapatır', (tester) async {
    await setup(tester);
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffold.openDrawer();
    await tester.pumpAndSettle();

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue, reason: 'uygulama kapanmamalı');
    expect(scaffold.isDrawerOpen, isFalse);
  });

  Future<_TabsModelState> startTest(WidgetTester tester) async {
    await setup(tester);
    await tester.tap(find.text('git2'));
    await tester.pump();
    final state = tester.state<_TabsModelState>(find.byType(_TabsModel));
    state.inProgress = true; // test başladı
    return state;
  }

  testWidgets('yarım testte geri tuşu onay ister; "Devam et" sekmede bırakır', (tester) async {
    await startTest(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Testten çıkılsın mı?'), findsOneWidget);
    expect(find.text('sekme 2'), findsOneWidget, reason: 'onaydan önce sekme değişmemeli');

    await tester.tap(find.text('Devam et'));
    await tester.pumpAndSettle();
    expect(find.text('Testten çıkılsın mı?'), findsNothing);
    expect(find.text('sekme 2'), findsOneWidget, reason: 'test sekmesinde kalmalı');
  });

  testWidgets('yarım testte geri tuşu + "Çık" Ana Sayfa dönüşü sağlar', (tester) async {
    final state = await startTest(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çık'));
    await tester.pumpAndSettle();
    expect(find.text('sekme 0'), findsOneWidget);
    expect(state.inProgress, isFalse);
  });

  testWidgets('yarım testte alt çubuktan başka sekmeye geçmek de onay ister', (tester) async {
    await startTest(tester);
    await tester.tap(find.text('git1'));
    await tester.pumpAndSettle();
    expect(find.text('Testten çıkılsın mı?'), findsOneWidget);
    expect(find.text('sekme 2'), findsOneWidget);

    await tester.tap(find.text('Çık'));
    await tester.pumpAndSettle();
    expect(find.text('sekme 1'), findsOneWidget);
  });

  testWidgets('test yokken veya bitmişken onay sorulmaz', (tester) async {
    await setup(tester);
    await tester.tap(find.text('git2'));
    await tester.pump();
    await tester.binding.handlePopRoute(); // inProgress=false
    await tester.pumpAndSettle();
    expect(find.text('Testten çıkılsın mı?'), findsNothing);
    expect(find.text('sekme 0'), findsOneWidget);
  });
}
