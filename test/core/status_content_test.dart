import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/core/status_content.dart';
import 'package:kanban_board/core/theme.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildDarkTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('StatusContent', () {
    testWidgets('renders icon and message', (tester) async {
      await tester.pumpWidget(_wrap(
        const StatusContent(
          icon: Icons.dashboard_outlined,
          message: 'No boards yet',
        ),
      ));

      expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
      expect(find.text('No boards yet'), findsOneWidget);
    });

    testWidgets('renders action widget when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        StatusContent(
          icon: Icons.error_outline,
          message: 'Something went wrong',
          action: TextButton(
            onPressed: () {},
            child: const Text('Retry'),
          ),
        ),
      ));

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('omits action spacing when action is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const StatusContent(
          icon: Icons.dashboard_outlined,
          message: 'No boards yet',
        ),
      ));

      // Only icon + SizedBox(16) + text = 3 children in the Column.
      final column = tester.widget<Column>(find.byType(Column).last);
      expect(column.children.length, 3);
    });

    testWidgets('includes action spacing when action is present',
        (tester) async {
      await tester.pumpWidget(_wrap(
        StatusContent(
          icon: Icons.error_outline,
          message: 'Something went wrong',
          action: TextButton(
            onPressed: () {},
            child: const Text('Retry'),
          ),
        ),
      ));

      // icon + SizedBox(16) + text + SizedBox(8) + action = 5 children.
      final column = tester.widget<Column>(find.byType(Column).last);
      expect(column.children.length, 5);
    });

    testWidgets('respects custom iconSize', (tester) async {
      await tester.pumpWidget(_wrap(
        const StatusContent(
          icon: Icons.note_outlined,
          message: 'No cards yet',
          iconSize: 36,
        ),
      ));

      final icon = tester.widget<Icon>(find.byIcon(Icons.note_outlined));
      expect(icon.size, 36);
    });

    testWidgets('respects custom iconColor', (tester) async {
      await tester.pumpWidget(_wrap(
        const StatusContent(
          icon: Icons.error_outline,
          message: 'Error',
          iconColor: Colors.red,
        ),
      ));

      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.color, Colors.red);
    });

    testWidgets('defaults iconColor to onSurfaceVariant', (tester) async {
      await tester.pumpWidget(_wrap(
        const StatusContent(
          icon: Icons.dashboard_outlined,
          message: 'Empty',
        ),
      ));

      final theme = buildDarkTheme();
      final icon = tester.widget<Icon>(find.byIcon(Icons.dashboard_outlined));
      expect(icon.color, theme.colorScheme.onSurfaceVariant);
    });

    testWidgets('wraps in Padding when padding is provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const StatusContent(
          icon: Icons.view_column_outlined,
          message: 'No columns yet',
          padding: EdgeInsets.symmetric(vertical: 24),
        ),
      ));

      // Padding widget wrapping the Center.
      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.byType(Center),
          matching: find.byType(Padding),
        ).first,
      );
      expect(
        padding.padding,
        const EdgeInsets.symmetric(vertical: 24),
      );
    });

    testWidgets('respects custom textStyle', (tester) async {
      final customStyle = buildDarkTheme().textTheme.bodyMedium!;

      await tester.pumpWidget(_wrap(
        StatusContent(
          icon: Icons.view_column_outlined,
          message: 'No columns yet',
          textStyle: customStyle,
        ),
      ));

      final text = tester.widget<Text>(find.text('No columns yet'));
      expect(text.style, customStyle);
    });
  });
}
