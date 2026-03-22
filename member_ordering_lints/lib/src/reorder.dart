import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/diagnostic/diagnostic.dart' show Severity;
import 'package:member_ordering_lints/src/classify.dart';

/// Returns the rewritten [source] with members reordered, or `null` if no
/// changes were needed.
String? reorderFile(String source) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );

  // Bail out if the file has parse errors — AST offsets may be unreliable.
  final hasErrors = result.errors
      .any((e) => e.severity == Severity.error);
  if (hasErrors) return null;

  final declarations = _collectDeclarations(result.unit);
  if (declarations.isEmpty) return null;

  // Process bottom-up so earlier offsets stay valid after splicing.
  declarations.sort((a, b) => b.offset.compareTo(a.offset));

  var changed = false;
  var output = source;

  for (final decl in declarations) {
    final edit = _reorderDeclaration(output, decl);
    if (edit == null) continue;
    changed = true;
    output = output.substring(0, edit.start) +
        edit.replacement +
        output.substring(edit.end);
  }

  return changed ? output : null;
}

// ---------------------------------------------------------------------------
// Declaration collection
// ---------------------------------------------------------------------------

/// Collects all class/enum/mixin/extension/extensionType declarations,
/// including nested ones.
List<AstNode> _collectDeclarations(CompilationUnit unit) {
  final visitor = _DeclarationCollector();
  unit.accept(visitor);
  return visitor.declarations;
}

class _DeclarationCollector extends RecursiveAstVisitor<void> {
  final List<AstNode> declarations = [];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    declarations.add(node);
    super.visitClassDeclaration(node);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    declarations.add(node);
    super.visitEnumDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    declarations.add(node);
    super.visitMixinDeclaration(node);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    declarations.add(node);
    super.visitExtensionDeclaration(node);
  }

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    declarations.add(node);
    super.visitExtensionTypeDeclaration(node);
  }
}

// ---------------------------------------------------------------------------
// Reorder a single declaration
// ---------------------------------------------------------------------------

({int start, int end, String replacement})? _reorderDeclaration(
  String source,
  AstNode decl,
) {
  final (members, regionStart, regionEnd) = _extractBodyInfo(decl);
  if (members == null || members.length < 2) return null;

  // Build chunks.  Each chunk owns the member's text *plus* any leading
  // whitespace, doc comments, and annotations that precede it.  We use
  // `beginToken.offset` which includes leading comments/annotations thanks
  // to the analyzer's `_AnnotatedNodeMixin`.
  //
  // Layout of the region:
  //   regionStart ... [gap0] member0 [gap1] member1
  //   ... memberN [trailing] regionEnd
  //
  // gap_i = whitespace/blank-lines between member_{i-1}.end and
  //         member_i.beginToken.offset.  We attach each gap to the
  //         *following* member so comments travel with their target.

  // Leading gap: whitespace between `{` (regionStart) and first member's
  // real start.  Preserved as a prefix to whichever member ends up first.
  final leadingGap = source.substring(
    regionStart,
    members[0].beginToken.offset,
  );

  final chunks = <_MemberChunk>[];
  for (var i = 0; i < members.length; i++) {
    // Gap before this member (whitespace between previous member's end and
    // this member's doc-comment/annotation start).  For the first member
    // the gap is handled separately as `leadingGap`.
    final gap = i == 0
        ? ''
        : source.substring(members[i - 1].end, members[i].beginToken.offset);
    final memberText = source.substring(
      members[i].beginToken.offset,
      members[i].end,
    );
    final category = classifyMember(members[i]);
    // Unclassified members keep their original position so the fixer
    // doesn't move constructs the lint rule ignores.
    final categoryIndex =
        category != null ? defaultOrder.indexOf(category) : i;
    chunks.add(_MemberChunk(
      gap: gap,
      memberText: memberText,
      categoryIndex: categoryIndex,
      originalIndex: i,
    ));
  }

  // Stable sort by (categoryIndex, originalIndex).
  chunks.sort((a, b) {
    final cmp = a.categoryIndex.compareTo(b.categoryIndex);
    return cmp != 0 ? cmp : a.originalIndex.compareTo(b.originalIndex);
  });

  // Check if order actually changed.
  var same = true;
  for (var i = 0; i < chunks.length; i++) {
    if (chunks[i].originalIndex != i) {
      same = false;
      break;
    }
  }
  if (same) return null;

  // Trailing content between last member and `}`.
  final trailing = source.substring(members.last.end, regionEnd);

  // Rebuild the region.
  final buffer = StringBuffer();
  for (var i = 0; i < chunks.length; i++) {
    final String gap;
    if (i == 0) {
      // First chunk in the output gets the original leading gap (whitespace
      // between `{` and the first member).
      gap = leadingGap;
    } else if (chunks[i].gap.isEmpty) {
      // This chunk was originally the first member (index 0) so it had no
      // gap.  Now it's been moved to a later position and needs a separator.
      // Use the leading gap as a fallback — it carries the newline + indent
      // pattern for this class body.
      gap = leadingGap;
    } else {
      gap = chunks[i].gap;
    }
    buffer
      ..write(gap)
      ..write(chunks[i].memberText);
  }
  buffer.write(trailing);

  return (start: regionStart, end: regionEnd, replacement: buffer.toString());
}

// ---------------------------------------------------------------------------
// Body info extraction
// ---------------------------------------------------------------------------

/// Returns (members, regionStart, regionEnd) for a declaration, or
/// (null, _, _) if the body has no reorderable members.
(NodeList<ClassMember>?, int, int) _extractBodyInfo(AstNode decl) {
  if (decl is EnumDeclaration) {
    final body = decl.body;
    if (body is! BlockEnumBody) return (null, 0, 0);
    final members = body.members;
    if (members.isEmpty) return (null, 0, 0);
    // Region starts after the semicolon separating constants from members,
    // or after `{` if there are no constants / no semicolon.
    final regionStart =
        body.semicolon?.end ?? body.leftBracket.end;
    final regionEnd = body.rightBracket.offset;
    return (members, regionStart, regionEnd);
  }

  // ClassDeclaration, MixinDeclaration, ExtensionDeclaration,
  // ExtensionTypeDeclaration all have a ClassBody.
  final ClassBody body;
  if (decl is ClassDeclaration) {
    body = decl.body;
  } else if (decl is MixinDeclaration) {
    body = decl.body;
  } else if (decl is ExtensionDeclaration) {
    body = decl.body;
  } else if (decl is ExtensionTypeDeclaration) {
    body = decl.body;
  } else {
    return (null, 0, 0);
  }

  if (body is! BlockClassBody) return (null, 0, 0);
  final members = body.members;
  if (members.isEmpty) return (null, 0, 0);
  return (members, body.leftBracket.end, body.rightBracket.offset);
}

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

class _MemberChunk {
  _MemberChunk({
    required this.gap,
    required this.memberText,
    required this.categoryIndex,
    required this.originalIndex,
  });

  /// Whitespace/blank-lines between the previous member and this one.
  final String gap;

  /// The member's source text (from beginToken including comments/annotations
  /// through to end).
  final String memberText;

  final int categoryIndex;
  final int originalIndex;
}
