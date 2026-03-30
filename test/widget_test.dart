import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histolink/main.dart';

void main() {
  testWidgets('App smoke test - muestra pantalla de carga', (WidgetTester tester) async {
    await tester.pumpWidget(const HistolinkApp());
    expect(find.text('Histolink'), findsWidgets);
  });
}
