// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lista_de_compras/main.dart';

void main() {
  testWidgets('exibe a tela de login', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    expect(find.text('Lista de Compras'), findsOneWidget);
    expect(find.text('Entre na sua conta para continuar'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
