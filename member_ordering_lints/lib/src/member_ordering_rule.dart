import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'package:member_ordering_lints/src/classify.dart';

// ---------------------------------------------------------------------------
// Rule
// ---------------------------------------------------------------------------

class MemberOrderingRule extends AnalysisRule {
  MemberOrderingRule()
    : super(
        name: 'member_ordering',
        description:
            'Enforce a consistent ordering of class, enum, mixin, '
            'and extension members.',
      );
  static const LintCode code = LintCode(
    'member_ordering',
    'Class member is out of order.',
    correctionMessage:
        'Reorder members to match the project convention.  '
        'Run `dart analyze` after fixing to verify.',
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry
      ..addClassDeclaration(this, visitor)
      ..addEnumDeclaration(this, visitor)
      ..addMixinDeclaration(this, visitor)
      ..addExtensionDeclaration(this, visitor)
      ..addExtensionTypeDeclaration(this, visitor);
  }
}

// ---------------------------------------------------------------------------
// Visitor
// ---------------------------------------------------------------------------

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _checkMembers(node.body.members);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    _checkMembers(node.body.members);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _checkMembers(node.body.members);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    _checkMembers(node.body.members);
  }

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    _checkMembers(node.body.members);
  }

  // ─── Core check ──────────────────────────────────────────────────

  void _checkMembers(NodeList<ClassMember> members) {
    if (members.length < 2) return;

    final classified = <(ClassMember, int)>[];
    for (final member in members) {
      final category = classifyMember(member);
      if (category == null) continue;
      classified.add((member, defaultOrder.indexOf(category)));
    }

    // Walk forward.  Whenever a member has a *lower* priority index than
    // the highest we've seen so far, it is out of place.
    var highestIndex = -1;
    for (final (member, index) in classified) {
      if (index < highestIndex) {
        // Report at the whole member declaration.  The IDE will
        // highlight the declaration, making it clear what to move.
        rule.reportAtNode(member);
      } else if (index > highestIndex) {
        highestIndex = index;
      }
    }
  }
}
