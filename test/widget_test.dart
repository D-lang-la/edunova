import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:edunova/main.dart';

void main() {
  testWidgets('EduNova muestra el acceso local', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
