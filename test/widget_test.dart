import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sawitappmobile/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(initialScreen: Scaffold()));
    await tester.pump();

    expect(find.byType(MyApp), findsOneWidget);
  });
}
