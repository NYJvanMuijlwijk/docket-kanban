import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:member_ordering_lints/src/classify.dart';
import 'package:test/test.dart';

/// Parse a class body and return the classified categories of its members.
List<MemberCategory?> _classify(String classBody) {
  final source = 'class _Test {\n$classBody\n}';
  final unit = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;
  final cls = unit.declarations.first as ClassDeclaration;
  return cls.body.members.map(classifyMember).toList();
}

MemberCategory? _classifySingle(String memberSource) {
  return _classify(memberSource).single;
}

void main() {
  group('fields', () {
    test('public static const', () {
      expect(
        _classifySingle('static const int x = 1;'),
        MemberCategory.publicStaticConstFields,
      );
    });

    test('public static', () {
      expect(
        _classifySingle('static int x = 1;'),
        MemberCategory.publicStaticFields,
      );
    });

    test('private static const falls into privateStaticFields', () {
      expect(
        _classifySingle('static const int _x = 1;'),
        MemberCategory.privateStaticFields,
      );
    });

    test('private static', () {
      expect(
        _classifySingle('static int _x = 1;'),
        MemberCategory.privateStaticFields,
      );
    });

    test('public final', () {
      expect(
        _classifySingle('final int x;'),
        MemberCategory.publicFinalFields,
      );
    });

    test('public mutable', () {
      expect(
        _classifySingle('int x = 0;'),
        MemberCategory.publicFields,
      );
    });

    test('private final', () {
      expect(
        _classifySingle('final int _x;'),
        MemberCategory.privateFinalFields,
      );
    });

    test('private mutable', () {
      expect(
        _classifySingle('int _x = 0;'),
        MemberCategory.privateFields,
      );
    });

    test('mixed-privacy multi-variable treated as private', () {
      // `int _a, b;` — treat as private (conservative).
      expect(
        _classifySingle('int _a = 0, b = 0;'),
        MemberCategory.privateFields,
      );
    });
  });

  group('constructors', () {
    test('unnamed constructor', () {
      expect(
        _classifySingle('_Test();'),
        MemberCategory.constructors,
      );
    });

    test('named constructor', () {
      expect(
        _classifySingle('_Test.named();'),
        MemberCategory.namedConstructors,
      );
    });

    test('factory constructor', () {
      expect(
        _classifySingle('factory _Test.create() => _Test();'),
        MemberCategory.factoryConstructors,
      );
    });
  });

  group('methods', () {
    test('public method', () {
      expect(
        _classifySingle('void doStuff() {}'),
        MemberCategory.publicMethods,
      );
    });

    test('private method', () {
      expect(
        _classifySingle('void _doStuff() {}'),
        MemberCategory.privateMethods,
      );
    });

    test('public override method', () {
      expect(
        _classifySingle('@override\nString toString() => "";'),
        MemberCategory.publicOverrideMethods,
      );
    });

    test('public getter', () {
      expect(
        _classifySingle('int get value => 0;'),
        MemberCategory.publicGetters,
      );
    });

    test('private getter', () {
      expect(
        _classifySingle('int get _value => 0;'),
        MemberCategory.privateGetters,
      );
    });

    test('public setter', () {
      expect(
        _classifySingle('set value(int v) {}'),
        MemberCategory.publicSetters,
      );
    });

    test('private setter', () {
      expect(
        _classifySingle('set _value(int v) {}'),
        MemberCategory.privateSetters,
      );
    });
  });

  group('build method', () {
    test('Widget build(BuildContext) is buildMethod', () {
      expect(
        _classifySingle(
          '@override\nWidget build(BuildContext context) => Container();',
        ),
        MemberCategory.buildMethod,
      );
    });

    test('Widget build(BuildContext, WidgetRef) is buildMethod', () {
      expect(
        _classifySingle(
          '@override\n'
          'Widget build(BuildContext context, WidgetRef ref) => Container();',
        ),
        MemberCategory.buildMethod,
      );
    });

    test('Riverpod build() with no params is publicOverrideMethods', () {
      expect(
        _classifySingle(
          '@override\nStream<List<int>> build() => Stream.empty();',
        ),
        MemberCategory.publicOverrideMethods,
      );
    });

    test('Riverpod build(Ref, String) is publicOverrideMethods', () {
      expect(
        _classifySingle(
          '@override\nFuture<int> build(Ref ref, String id) async => 0;',
        ),
        MemberCategory.publicOverrideMethods,
      );
    });

    test('private _build is privateMethods', () {
      expect(
        _classifySingle('Widget _build() => Container();'),
        MemberCategory.privateMethods,
      );
    });
  });

  group('defaultOrder validation', () {
    test('defaultOrder contains every MemberCategory exactly once', () {
      expect(defaultOrder.length, MemberCategory.values.length);
      expect(defaultOrder.toSet().length, defaultOrder.length);
    });
  });
}
