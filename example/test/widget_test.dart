import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mole_example/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpTall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MoleExampleApp());
    await tester.pump();
    await tester.pump();
  }

  testWidgets('example app renders the 4 storage sections', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpTall(tester);

    expect(find.text('SharedPreferences'), findsOneWidget);
    expect(find.text('Secure Storage'), findsOneWidget);
    expect(find.text('Hive'), findsOneWidget);
    expect(find.text('Cache'), findsOneWidget);
  });

  testWidgets('name field previews an already-stored value', (tester) async {
    SharedPreferences.setMockInitialValues({'name': 'Mole'});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MoleExampleApp(prefs: prefs));
    await tester.pump();
    await tester.pump(); // prefs-first init settles before Hive

    final field = tester.widget<TextField>(
      find.byWidgetPredicate((w) => w is TextField),
    );
    expect(field.controller?.text, 'Mole');
  });
}