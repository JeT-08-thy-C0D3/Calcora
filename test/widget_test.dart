import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:demo_calc/main.dart';

void main() {
  testWidgets('Calcora opens with its scientific calculator controls', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CalcoraApp());

    expect(find.text('Calcora'), findsOneWidget);
    expect(find.text('sin('), findsOneWidget);
    expect(find.text('='), findsOneWidget);
    expect(find.text('ANS'), findsOneWidget);
  });

  testWidgets('calculator fits a compact screen and reuses the previous answer',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const CalcoraApp());
    await tester.tap(find.text('7'));
    await tester.tap(find.text('+'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('='));
    await tester.pump();
    expect(find.text('9'), findsWidgets);

    await tester.tap(find.text('ANS'));
    await tester.tap(find.text('+'));
    await tester.tap(find.text('1'));
    await tester.tap(find.text('='));
    await tester.pump();
    expect(find.text('10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('scientific expressions use degrees', () {
    expect(ExpressionParser('sin(90) + sqrt(9) * 2').parse(), closeTo(7, .00001));
  });
}
