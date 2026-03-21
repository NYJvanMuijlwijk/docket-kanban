import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/main.dart';

void main() {
  testWidgets('App renders home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KanbanApp()));
    await tester.pumpAndSettle();

    expect(find.text('Kanban Board'), findsWidgets);
    expect(find.text('Welcome to Kanban Board'), findsOneWidget);
  });

  testWidgets('App uses dark theme by default', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KanbanApp()));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(materialApp.themeMode, ThemeMode.dark);
  });
}
