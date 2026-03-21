import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'package:member_ordering_lints/src/classify.dart';

/// Returns the rewritten [source] with members reordered, or `null` if no
/// changes were needed.
String? reorderFile(String source) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );

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

  // Build chunks: each chunk = text from end-of-previous-member to
  // end-of-this-member.  The first chunk starts at regionStart.
  final chunks = <_MemberChunk>[];
  for (var i = 0; i < members.length; i++) {
    final chunkStart = i == 0 ? regionStart : members[i - 1].end;
    final chunkEnd = members[i].end;
    final category = classifyMember(members[i]);
    final categoryIndex =
        category != null ? defaultOrder.indexOf(category) : -1;
    chunks.add(_MemberChunk(
      sourceStart: chunkStart,
      sourceEnd: chunkEnd,
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
  for (final chunk in chunks) {
    buffer.write(source.substring(chunk.sourceStart, chunk.sourceEnd));
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
    required this.sourceStart,
    required this.sourceEnd,
    required this.categoryIndex,
    required this.originalIndex,
  });

  final int sourceStart;
  final int sourceEnd;
  final int categoryIndex;
  final int originalIndex;
}
