import 'package:analyzer/dart/ast/ast.dart';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// Categories a class member can be classified as.
///
/// **To customise the ordering**, rearrange the entries in [defaultOrder]
/// below.  The plugin reads that list at startup — no YAML config needed.
enum MemberCategory {
  publicStaticConstFields('public static const field'),
  publicStaticFields('public static field'),
  privateStaticFields('private static field'),
  publicFinalFields('public final field'),
  publicFields('public field'),
  privateFinalFields('private final field'),
  privateFields('private field'),
  constructors('constructor'),
  namedConstructors('named constructor'),
  factoryConstructors('factory constructor'),
  publicOverrideMethods('public override method'),
  publicGetters('public getter'),
  publicSetters('public setter'),
  publicMethods('public method'),
  buildMethod('build method'),
  privateGetters('private getter'),
  privateSetters('private setter'),
  privateMethods('private method')
  ;

  const MemberCategory(this.displayName);
  final String displayName;
}

/// The enforced ordering.  Edit this list to change the convention.
///
/// Every category must appear exactly once.  Validated at runtime by
/// [_assertDefaultOrderValid].
const List<MemberCategory> defaultOrder = [
  // public-constructor
  MemberCategory.constructors,
  // named-constructors
  MemberCategory.namedConstructors,
  MemberCategory.factoryConstructors,
  // public-static-variables
  MemberCategory.publicStaticConstFields,
  MemberCategory.publicStaticFields,
  // public-instance-variables
  MemberCategory.publicFinalFields,
  MemberCategory.publicFields,
  MemberCategory.publicGetters,
  MemberCategory.publicSetters,
  // private-static-variables
  MemberCategory.privateStaticFields,
  // private-instance-variables
  MemberCategory.privateFinalFields,
  MemberCategory.privateFields,
  MemberCategory.privateGetters,
  MemberCategory.privateSetters,
  // public-override-methods
  MemberCategory.publicOverrideMethods,
  // public-other-methods
  MemberCategory.publicMethods,
  // private-other-methods
  MemberCategory.privateMethods,
  // build-method
  MemberCategory.buildMethod,
];

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

bool _assertedOrderValid = false;

void _assertDefaultOrderValid() {
  if (_assertedOrderValid) return;
  final length = defaultOrder.length;
  final unique = defaultOrder.toSet().length;
  assert(
    length == MemberCategory.values.length && unique == length,
    'defaultOrder must contain every MemberCategory exactly once. '
    'Expected ${MemberCategory.values.length}, got $length ($unique unique).',
  );
  _assertedOrderValid = true;
}

// ---------------------------------------------------------------------------
// Classification
// ---------------------------------------------------------------------------

MemberCategory? classifyMember(ClassMember member) {
  _assertDefaultOrderValid();
  if (member is FieldDeclaration) return _classifyField(member);
  if (member is ConstructorDeclaration) return _classifyConstructor(member);
  if (member is MethodDeclaration) return _classifyMethod(member);
  return null;
}

MemberCategory _classifyField(FieldDeclaration node) {
  final isStatic = node.isStatic;
  final isConst = node.fields.isConst;
  final isFinal = node.fields.isFinal;
  final variables = node.fields.variables;
  final anyPrivate = variables.any((v) => v.name.lexeme.startsWith('_'));

  // Mixed-privacy multi-variable declaration (e.g. `int _a, b;`) — treat as
  // private so it sorts conservatively and the ordering warning draws attention
  // to the problematic declaration.
  final isPrivate = anyPrivate;

  if (isStatic && isConst && !isPrivate) {
    return MemberCategory.publicStaticConstFields;
  }
  if (isStatic && !isPrivate) return MemberCategory.publicStaticFields;
  // Private static const fields intentionally land here — a separate
  // `privateStaticConstFields` category isn't useful in practice since
  // private statics are rarely mutable.
  if (isStatic && isPrivate) return MemberCategory.privateStaticFields;
  if (isFinal && !isPrivate) return MemberCategory.publicFinalFields;
  if (!isPrivate) return MemberCategory.publicFields;
  if (isFinal && isPrivate) return MemberCategory.privateFinalFields;
  return MemberCategory.privateFields;
}

MemberCategory _classifyConstructor(ConstructorDeclaration node) {
  if (node.factoryKeyword != null) return MemberCategory.factoryConstructors;
  if (node.name != null) return MemberCategory.namedConstructors;
  return MemberCategory.constructors;
}

MemberCategory _classifyMethod(MethodDeclaration node) {
  final name = node.name.lexeme;
  final isPrivate = name.startsWith('_');
  final isOverride = node.metadata.any((m) => m.name.name == 'override');

  // Only classify as `buildMethod` if the signature looks like a Widget build
  // (first positional parameter is BuildContext).  Riverpod notifier `build()`
  // methods have no parameters or start with Ref, so they fall through to
  // `publicOverrideMethods` instead.
  if (name == 'build' && !isPrivate && _isWidgetBuild(node)) {
    return MemberCategory.buildMethod;
  }

  if (node.isGetter) {
    return isPrivate
        ? MemberCategory.privateGetters
        : MemberCategory.publicGetters;
  }
  if (node.isSetter) {
    return isPrivate
        ? MemberCategory.privateSetters
        : MemberCategory.publicSetters;
  }
  if (isOverride && !isPrivate) return MemberCategory.publicOverrideMethods;
  if (!isPrivate) return MemberCategory.publicMethods;
  return MemberCategory.privateMethods;
}

/// Returns `true` if [node] looks like a Widget `build` method — i.e. its
/// first positional parameter is typed `BuildContext`.
///
/// Riverpod notifier `build()` methods have zero parameters (or start with
/// `Ref`), so this returns `false` for them.
bool _isWidgetBuild(MethodDeclaration node) {
  final params = node.parameters?.parameters;
  if (params == null || params.isEmpty) return false;
  final first = params.first;
  // The parameter could be a SimpleFormalParameter with an explicit type,
  // or a FunctionTypedFormalParameter, etc.  We only care about the simple
  // case with a named type.
  if (first is! SimpleFormalParameter) return false;
  final type = first.type;
  if (type is! NamedType) return false;
  return type.name.lexeme == 'BuildContext';
}
