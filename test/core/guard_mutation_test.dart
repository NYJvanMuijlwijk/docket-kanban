import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/core/guard_mutation.dart';
import 'package:kanban_board/core/mutation_exception.dart';

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

    await guardMutation(savedContext, () async {});
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('ValidationException shows e.message in SnackBar',
      (tester) async {
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
      () async =>
          throw const ValidationException('Board already has 10 columns'),
    );
    await tester.pump();

    expect(find.text('Board already has 10 columns'), findsOneWidget);
  });

  testWidgets('StaleDataException shows e.message in SnackBar',
      (tester) async {
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
      () async =>
          throw const StaleDataException('Board was already deleted'),
    );
    await tester.pump();

    expect(find.text('Board was already deleted'), findsOneWidget);
  });

  testWidgets('StorageException shows e.message in SnackBar',
      (tester) async {
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
      () async => throw const StorageException("Couldn't save board"),
    );
    await tester.pump();

    expect(find.text("Couldn't save board"), findsOneWidget);
  });

  testWidgets('unknown Exception shows generic fallback', (tester) async {
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
      () async => throw Exception('unexpected'),
    );
    await tester.pump();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('unexpected'), findsNothing);
  });

  testWidgets('returns action result on success', (tester) async {
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

    final result = await guardMutation(savedContext, () async => 42);

    expect(result, 42);
  });

  testWidgets('returns null on MutationException', (tester) async {
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

    final result = await guardMutation<int>(
      savedContext,
      () async => throw const ValidationException('limit reached'),
    );
    await tester.pump();

    expect(result, isNull);
  });

  testWidgets('returns null on unknown Exception', (tester) async {
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

    final result = await guardMutation<String>(
      savedContext,
      () async => throw Exception('unexpected'),
    );
    await tester.pump();

    expect(result, isNull);
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
      () async =>
          throw const ValidationException('Board already has 10 columns'),
    );
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });
}
