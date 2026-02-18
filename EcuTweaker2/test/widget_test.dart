// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:ecutweaker2/main.dart';

void main() {
  testWidgets('App boots and shows home', (WidgetTester tester) async {
    await tester.pumpWidget(const EcuTweaker2App());
    await tester.pumpAndSettle();

    expect(find.text('EcuTweaker 2'), findsWidgets);
    expect(find.text('Disconnected'), findsOneWidget);

    // Bottom navigation destinations exist
    expect(find.text('ECU'), findsOneWidget);
    expect(find.text('Connection'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
