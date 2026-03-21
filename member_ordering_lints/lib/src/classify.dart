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
/// Every category must appear exactly once.
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
// Classification
// ---------------------------------------------------------------------------

MemberCategory? classifyMember(ClassMember member) {
  if (member is FieldDeclaration) return _classifyField(member);
  if (member is ConstructorDeclaration) return _classifyConstructor(member);
  if (member is MethodDeclaration) return _classifyMethod(member);
  return null;
}

MemberCategory _classifyField(FieldDeclaration node) {
  final isStatic = node.isStatic;
  final isConst =
      node.fields.isConst ||
      (node.fields.isFinal &&
          isStatic &&
          node.fields.variables.every((v) => v.initializer != null));
  final isFinal = node.fields.isFinal;
  final isPrivate = node.fields.variables.first.name.lexeme.startsWith('_');

  if (isStatic && isConst && !isPrivate) {
    return MemberCategory.publicStaticConstFields;
  }
  if (isStatic && !isPrivate) return MemberCategory.publicStaticFields;
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

  if (name == 'build' && !isPrivate) return MemberCategory.buildMethod;

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
