import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Categories a class member can be classified as.
///
/// The enum order here defines the DEFAULT ordering.
/// Override via analysis_options.yaml to change it.
enum MemberCategory {
  publicStaticConstFields('public-static-const-fields'),
  publicStaticFields('public-static-fields'),
  privateStaticFields('private-static-fields'),
  publicFinalFields('public-final-fields'),
  publicFields('public-fields'),
  privateFinalFields('private-final-fields'),
  privateFields('private-fields'),
  constructors('constructors'),
  namedConstructors('named-constructors'),
  factoryConstructors('factory-constructors'),
  publicOverrideMethods('public-override-methods'),
  publicGetters('public-getters'),
  publicSetters('public-setters'),
  publicMethods('public-methods'),
  buildMethod('build-method'),
  privateGetters('private-getters'),
  privateSetters('private-setters'),
  privateMethods('private-methods');

  const MemberCategory(this.configKey);
  final String configKey;

  static MemberCategory? fromKey(String key) {
    for (final category in values) {
      if (category.configKey == key) return category;
    }
    return null;
  }
}

/// A lint rule that enforces consistent ordering of class members.
///
/// Enable and configure in analysis_options.yaml:
/// ```yaml
/// custom_lint:
///   rules:
///     - member_ordering  # uses default ordering
/// ```
///
/// Or with a custom order (list only the categories you care about;
/// unlisted categories are appended at the end):
/// ```yaml
/// custom_lint:
///   rules:
///     - member_ordering:
///       order:
///         - constructors
///         - named-constructors
///         - factory-constructors
///         - public-static-const-fields
///         - public-static-fields
///         - private-static-fields
///         - public-final-fields
///         - public-fields
///         - private-final-fields
///         - private-fields
///         - public-override-methods
///         - build-method
///         - public-getters
///         - public-setters
///         - public-methods
///         - private-getters
///         - private-setters
///         - private-methods
/// ```
class MemberOrderingRule extends DartLintRule {
  MemberOrderingRule({
    List<MemberCategory>? order,
  }) : _order = order ?? MemberCategory.values.toList(),
       super(code: _code);

  factory MemberOrderingRule.fromConfigs(CustomLintConfigs configs) {
    final ruleConfig = configs.rules['member_ordering'];
    final orderOption = ruleConfig?.json['order'];

    List<MemberCategory>? order;
    if (orderOption is List) {
      final parsed = <MemberCategory>[];
      final seen = <MemberCategory>{};
      for (final entry in orderOption) {
        final cat = MemberCategory.fromKey(entry.toString());
        if (cat != null && seen.add(cat)) {
          parsed.add(cat);
        }
      }
      // Append any categories not listed so nothing is silently ignored.
      for (final cat in MemberCategory.values) {
        if (seen.add(cat)) parsed.add(cat);
      }
      order = parsed;
    }

    return MemberOrderingRule(order: order);
  }

  final List<MemberCategory> _order;

  static const _code = LintCode(
    name: 'member_ordering',
    problemMessage:
        '{0} should come before {1}. '
        'Expected order: {2} before {3}.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkMembers(node.members, node.name.lexeme, reporter);
    });

    context.registry.addEnumDeclaration((node) {
      _checkMembers(node.members, node.name.lexeme, reporter);
    });

    context.registry.addMixinDeclaration((node) {
      _checkMembers(node.members, node.name.lexeme, reporter);
    });

    context.registry.addExtensionDeclaration((node) {
      _checkMembers(
        node.members,
        node.name?.lexeme ?? '<extension>',
        reporter,
      );
    });

    context.registry.addExtensionTypeDeclaration((node) {
      _checkMembers(node.members, node.name.lexeme, reporter);
    });
  }

  void _checkMembers(
    NodeList<ClassMember> members,
    String className,
    ErrorReporter reporter,
  ) {
    if (members.length < 2) return;

    final categorized = <(ClassMember, MemberCategory, String)>[];
    for (final member in members) {
      final category = _classify(member);
      if (category == null) continue; // skip unrecognized
      categorized.add((member, category, _memberLabel(member)));
    }

    // Walk through the list and report any member that appears after
    // a member with a higher-priority (lower index) category.
    var highestSeenIndex = -1;
    String? highestSeenLabel;
    MemberCategory? highestSeenCategory;

    for (final (member, category, label) in categorized) {
      final index = _order.indexOf(category);

      if (index < highestSeenIndex) {
        reporter.atNode(
          _reportTarget(member),
          _code,
          arguments: [
            label,
            highestSeenLabel ?? '?',
            category.configKey,
            highestSeenCategory?.configKey ?? '?',
          ],
        );
      } else if (index > highestSeenIndex) {
        highestSeenIndex = index;
        highestSeenLabel = label;
        highestSeenCategory = category;
      }
    }
  }

  // ─── Classification ──────────────────────────────────────────────

  MemberCategory? _classify(ClassMember member) {
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
            node.fields.variables.every(
              (v) => v.initializer != null,
            ));
    final isFinal = node.fields.isFinal;
    final isPrivate = _firstVarName(node).startsWith('_');

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
    final isOverride = _hasOverrideAnnotation(node);

    // build method (Flutter)
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

  // ─── Helpers ─────────────────────────────────────────────────────

  bool _hasOverrideAnnotation(MethodDeclaration node) {
    return node.metadata.any((m) => m.name.name == 'override');
  }

  String _firstVarName(FieldDeclaration node) {
    return node.fields.variables.first.name.lexeme;
  }

  /// Returns a human-readable label for a member, used in the warning message.
  String _memberLabel(ClassMember member) {
    if (member is FieldDeclaration) {
      return 'field "${_firstVarName(member)}"';
    }
    if (member is ConstructorDeclaration) {
      final name = member.name?.lexeme;
      if (member.factoryKeyword != null) {
        return name != null ? 'factory "$name"' : 'factory constructor';
      }
      return name != null ? 'constructor "$name"' : 'constructor';
    }
    if (member is MethodDeclaration) {
      final kind =
          member.isGetter
              ? 'getter'
              : member.isSetter
              ? 'setter'
              : 'method';
      return '$kind "${member.name.lexeme}"';
    }
    return 'member';
  }

  /// Returns the AST node to underline in the IDE for a given member.
  AstNode _reportTarget(ClassMember member) {
    if (member is FieldDeclaration) {
      return member.fields.variables.first;
    }
    if (member is ConstructorDeclaration) {
      return member.returnType;
    }
    if (member is MethodDeclaration) {
      return member;
    }
    return member;
  }
}
