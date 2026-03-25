import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/core/guard_mutation.dart';

void main() {
  testWidgets('no SnackBar on success', (tester) async {
    late BuildContext savedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              savedContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    await guardMutation(savedContext, () async {}, 'fail');
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('StateError shows e.message in SnackBar', (tester) async {
    late BuildContext savedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              savedContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    await guardMutation(
      savedContext,
      () async => throw StateError('Board already has 10 columns'),
      'Failed to create column',
    );
    await tester.pump();

    expect(find.text('Board already has 10 columns'), findsOneWidget);
    expect(find.text('Failed to create column'), findsNothing);
  });

  testWidgets('ArgumentError shows generic failureMessage', (tester) async {
    late BuildContext savedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              savedContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    await guardMutation(
      savedContext,
      () async => throw ArgumentError('Board not found: abc'),
      'Failed to rename board',
    );
    await tester.pump();

    expect(find.text('Failed to rename board'), findsOneWidget);
    expect(find.text('Board not found: abc'), findsNothing);
  });

  testWidgets('no crash when context is unmounted', (tester) async {
    late BuildContext savedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              savedContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    // Unmount the widget tree before the action throws.
    await tester.pumpWidget(const SizedBox());

    // Should not crash — context is unmounted, SnackBar cannot be shown.
    await guardMutation(
      savedContext,
      () async => throw StateError('limit'),
      'fail',
    );
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });
}
