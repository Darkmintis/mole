import 'package:flutter_test/flutter_test.dart';
import 'package:mole_example/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('example app renders storage demo UI', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MoleExampleApp());
    await tester.pump();

    expect(find.text('SharedPreferences'), findsOneWidget);
    expect(find.text('Hive box'), findsOneWidget);
    expect(find.text('Secure Storage'), findsOneWidget);
  });
}