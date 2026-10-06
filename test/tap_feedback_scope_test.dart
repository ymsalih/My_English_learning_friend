import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingilizce_destek_app/widgets/app_bottom_bar.dart';
import 'package:ingilizce_destek_app/widgets/tap_feedback_scope.dart';

void main() {
  testWidgets('yalnızca gerçek dokunuşlarda geri bildirim verir', (tester) async {
    var count = 0;
    var pressed = 0;
    await tester.pumpWidget(MaterialApp(
      home: TapFeedbackScope(
        onTap: () => count++,
        child: Scaffold(
          body: ListView(children: [
            ElevatedButton(key: const Key('btn'), onPressed: () => pressed++, child: const Text('Buton')),
            const ElevatedButton(key: Key('disabled'), onPressed: null, child: Text('Pasif')),
            GestureDetector(key: const Key('gd'), onTap: () => pressed++, child: const SizedBox(height: 60, width: 200, child: Text('GD'))),
            InkWell(key: const Key('ink'), onTap: () => pressed++, child: const SizedBox(height: 60, width: 200, child: Text('Ink'))),
            const ListTile(key: Key('tile'), title: Text('Tile'), onTap: null),
            ListTile(key: const Key('tile2'), title: const Text('Tile2'), onTap: () => pressed++),
            const TextField(key: Key('field')),
            const SizedBox(key: Key('empty'), height: 80, width: 200),
          ]),
        ),
      ),
    ));

    Future<int> tapAndCount(Key k) async {
      final before = count;
      await tester.tap(find.byKey(k));
      await tester.pump(const Duration(milliseconds: 100));
      return count - before;
    }

    expect(await tapAndCount(const Key('btn')), 1, reason: 'ElevatedButton');
    expect(await tapAndCount(const Key('gd')), 1, reason: 'GestureDetector');
    expect(await tapAndCount(const Key('ink')), 1, reason: 'InkWell');
    expect(await tapAndCount(const Key('tile2')), 1, reason: 'ListTile (aktif)');
    expect(await tapAndCount(const Key('disabled')), 0, reason: 'devre dışı buton');
    expect(await tapAndCount(const Key('tile')), 0, reason: 'devre dışı ListTile');
    expect(await tapAndCount(const Key('field')), 0, reason: 'yazı alanı');
    expect(await tapAndCount(const Key('empty')), 0, reason: 'boş alan');
    expect(pressed, 4, reason: 'butonların kendi işlevi bozulmamalı');

    // Sürükleme dokunuş sayılmaz.
    final before = count;
    await tester.drag(find.byKey(const Key('btn')), const Offset(0, -120));
    await tester.pump(const Duration(milliseconds: 100));
    expect(count - before, 0, reason: 'kaydırma');

    // Uzun basma dokunuş sayılmaz (olay zaman damgaları elle verilir).
    final pos = tester.getCenter(find.byKey(const Key('gd')));
    final pointer = TestPointer(7);
    await tester.sendEventToBinding(pointer.down(pos, timeStamp: Duration.zero));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendEventToBinding(pointer.up(timeStamp: const Duration(milliseconds: 600)));
    expect(count - before, 0, reason: 'uzun basma');

    // Kısa dokunuş (120 ms) sayılır.
    await tester.sendEventToBinding(pointer.down(pos, timeStamp: const Duration(milliseconds: 1000)));
    await tester.sendEventToBinding(pointer.up(timeStamp: const Duration(milliseconds: 1120)));
    expect(count - before, 1, reason: 'kısa dokunuş');
  });

  testWidgets('alt çubuk: sekme seçer ve geri bildirim verir', (tester) async {
    var count = 0;
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
      home: TapFeedbackScope(
        onTap: () => count++,
        child: Scaffold(
          bottomNavigationBar: AppBottomBar(
            selectedIndex: selected,
            onSelected: (i) => selected = i,
            items: const [
              AppBottomBarItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Ana'),
              AppBottomBarItem(icon: Icons.quiz_outlined, selectedIcon: Icons.quiz, label: 'Test'),
            ],
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Test'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(selected, 1, reason: 'sekme seçilmeli');
    expect(count, 1, reason: 'geri bildirim verilmeli');
  });
}
