import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tolerance_tool/presentation/widgets/home_quick_cards.dart';

void main() {
  testWidgets('首页四卡在窄屏下不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeQuickCards(
                onOpenSolver: () {},
                onOpenSearch: () {},
                onOpenTools: () {},
                onOpenGdnt: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('公差反选求解'), findsOneWidget);
    expect(find.text('机械小工具'), findsOneWidget);
  });
}
