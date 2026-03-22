import 'package:member_ordering_lints/src/reorder.dart';
import 'package:test/test.dart';

void main() {
  group('reorderFile', () {
    test('returns null when already in order', () {
      const source = '''
class Foo {
  Foo();
  final int x;
  void doStuff() {}
}
''';
      expect(reorderFile(source), isNull);
    });

    test('returns null on parse errors', () {
      const source = '''
class Foo {
  void broken( {}
}
''';
      expect(reorderFile(source), isNull);
    });

    test('reorders fields before methods', () {
      const source = '''
class Foo {
  void doStuff() {}
  final int x;
}
''';
      final result = reorderFile(source);
      expect(result, isNotNull);
      // Field should come before method after reorder.
      final xIndex = result!.indexOf('final int x;');
      final methodIndex = result.indexOf('void doStuff()');
      expect(xIndex, lessThan(methodIndex));
    });

    test('moves constructor above fields', () {
      const source = '''
class Foo {
  final int x;
  Foo(this.x);
}
''';
      final result = reorderFile(source);
      expect(result, isNotNull);
      final ctorIndex = result!.indexOf('Foo(this.x)');
      final fieldIndex = result.indexOf('final int x');
      expect(ctorIndex, lessThan(fieldIndex));
    });

    test('doc comments travel with their member', () {
      const source = '''
class Foo {
  void doStuff() {}

  /// The name of the foo.
  final String name;
}
''';
      final result = reorderFile(source);
      expect(result, isNotNull);
      // After reorder, `name` field moves above `doStuff`.
      // The doc comment must stay attached to `name`.
      final nameIndex = result!.indexOf('final String name;');
      final commentIndex = result.indexOf('/// The name of the foo.');
      final methodIndex = result.indexOf('void doStuff()');
      // Comment should be right before the field, both above the method.
      expect(commentIndex, lessThan(nameIndex));
      expect(nameIndex, lessThan(methodIndex));
      // Comment should NOT appear after the method.
      expect(commentIndex, lessThan(methodIndex));
    });

    test('annotations travel with their member', () {
      const source = '''
class Foo {
  void doStuff() {}

  @override
  String toString() => 'Foo';
}
''';
      final result = reorderFile(source);
      expect(result, isNotNull);
      // @override toString should move above doStuff (publicOverrideMethods
      // before publicMethods in defaultOrder).
      final overrideIndex = result!.indexOf('@override');
      final toStringIndex = result.indexOf('String toString()');
      final doStuffIndex = result.indexOf('void doStuff()');
      expect(overrideIndex, lessThan(toStringIndex));
      expect(toStringIndex, lessThan(doStuffIndex));
    });

    test('multi-line doc comment stays with member', () {
      const source = '''
class Foo {
  void z() {}

  /// First line.
  ///
  /// Second paragraph.
  final int a;
}
''';
      final result = reorderFile(source);
      expect(result, isNotNull);
      final firstLine = result!.indexOf('/// First line.');
      final secondPara = result.indexOf('/// Second paragraph.');
      final field = result.indexOf('final int a;');
      final method = result.indexOf('void z()');
      // Entire doc comment block must be before the field and above the method.
      expect(firstLine, lessThan(secondPara));
      expect(secondPara, lessThan(field));
      expect(field, lessThan(method));
    });

    test('Widget build stays at bottom', () {
      const source = '''
class MyWidget {
  @override
  Widget build(BuildContext context) => Container();
  final int x;
}
''';
      final result = reorderFile(source);
      expect(result, isNotNull);
      final fieldIndex = result!.indexOf('final int x;');
      final buildIndex = result.indexOf('Widget build(BuildContext context)');
      expect(fieldIndex, lessThan(buildIndex));
    });

    test('Riverpod build() sorts as override not as buildMethod', () {
      // Riverpod build() has no BuildContext parameter.  It should be
      // classified as publicOverrideMethods, not buildMethod.
      const source = '''
class MyNotifier {
  void doMutation() {}

  @override
  Stream<int> build() => Stream.empty();
}
''';
      final result = reorderFile(source);
      expect(result, isNotNull);
      // build() as an override should sort before doMutation (a public method).
      final buildIndex = result!.indexOf('Stream<int> build()');
      final mutIndex = result.indexOf('void doMutation()');
      expect(buildIndex, lessThan(mutIndex));
    });

    test('first member moved later gets proper whitespace gap', () {
      // Regression: when the originally-first member (index 0) is moved to a
      // later position, it had an empty gap and produced `}void ...` with no
      // separator.
      const source = '''
class Notifier {
  Future<int> createThing() async => 0;

  @override
  Stream<int> build() => Stream.empty();
}
''';
      final result = reorderFile(source);
      expect(result, isNotNull);
      // build() moves above createThing().  Verify no jammed-together text.
      expect(result, isNot(contains('}Future')));
      expect(result, isNot(contains('}Stream')));
      // Both members should be separated by whitespace.
      const marker = 'Stream.empty();';
      final buildEnd =
          result!.indexOf(marker) + marker.length;
      final createStart = result.indexOf('Future<int> createThing');
      // There must be at least a newline between them.
      final between = result.substring(buildEnd, createStart);
      expect(between.trim(), isEmpty,
          reason: 'gap between members should be whitespace only');
      expect(between, contains('\n'),
          reason: 'there must be a newline separating the two members');
    });

    test('output is idempotent', () {
      const source = '''
class Foo {
  void doStuff() {}
  final int x;
  Foo();
}
''';
      final first = reorderFile(source);
      expect(first, isNotNull);
      // Running the fixer on its own output should produce null (no changes).
      expect(reorderFile(first!), isNull);
    });

    test('handles class with single member (no reorder needed)', () {
      const source = '''
class Foo {
  final int x;
}
''';
      expect(reorderFile(source), isNull);
    });

    test('handles multiple classes in one file', () {
      const source = '''
class A {
  void z() {}
  final int a;
}

class B {
  void y() {}
  A() {}
}
''';
      final result = reorderFile(source);
      expect(result, isNotNull);
      // Class A: field should come before method.
      final aField = result!.indexOf('final int a;');
      final aMethod = result.indexOf('void z()');
      expect(aField, lessThan(aMethod));
    });
  });
}
