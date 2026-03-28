import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board/core/confirm_dialog.dart';
import 'package:kanban_board/core/guard_mutation.dart';
import 'package:kanban_board/core/sheet_body.dart';
import 'package:kanban_board/core/shimmer.dart';
import 'package:kanban_board/core/status_content.dart';
import 'package:kanban_board/core/string_utils.dart';
import 'package:kanban_board/features/board/domain/kanban_column.dart';
import 'package:kanban_board/features/board/presentation/providers/card_providers.dart';
import 'package:kanban_board/features/board/presentation/providers/column_providers.dart';

class ColumnManagementSheet extends ConsumerWidget {
  const ColumnManagementSheet({required this.boardId, super.key});

  final String boardId;

  static Future<void> show(
    BuildContext context, {
    required String boardId,
  }) {
    return showAppBottomSheet<void>(
      context,
      child: ColumnManagementSheet(boardId: boardId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columnsAsync = ref.watch(columnListProvider(boardId));
    final screenHeight = MediaQuery.sizeOf(context).height;

    return SheetBody(
      children: [
        _SheetHeader(
          columnCount: columnsAsync.value?.length ?? 0,
        ),
        const SizedBox(height: 16),
        columnsAsync.when(
          loading: () => const _SheetColumnSkeleton(),
          error: (_, _) => StatusContent(
            icon: Icons.error_outline,
            iconSize: 36,
            iconColor: Theme.of(context).colorScheme.error,
            message: 'Something went wrong',
            textStyle: Theme.of(context).textTheme.bodyMedium,
            action: TextButton(
              onPressed: () => ref.invalidate(columnListProvider(boardId)),
              child: const Text('Retry'),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          data: (columns) {
            if (columns.isEmpty) {
              return StatusContent(
                icon: Icons.view_column_outlined,
                iconSize: 36,
                message: 'No columns yet',
                textStyle: Theme.of(context).textTheme.bodyMedium,
                padding: const EdgeInsets.symmetric(vertical: 24),
              );
            }
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: screenHeight * 0.5,
              ),
              child: _ReorderableColumnList(
                columns: columns,
                boardId: boardId,
              ),
            );
          },
        ),
        const Divider(),
        _AddColumnField(
          boardId: boardId,
          atLimit:
              (columnsAsync.value?.length ?? 0) >= maxColumnsPerBoard,
        ),
      ],
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.columnCount});

  final int columnCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Manage Columns',
            style: theme.textTheme.titleLarge,
          ),
        ),
        Text(
          '$columnCount / $maxColumnsPerBoard',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ReorderableColumnList extends ConsumerWidget {
  const _ReorderableColumnList({
    required this.columns,
    required this.boardId,
  });

  final List<KanbanColumn> columns;
  final String boardId;

  Future<bool> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    KanbanColumn column,
  ) async {
    final cardCount = ref.read(cardListProvider(column.id)).value?.length ?? 0;

    final confirmed = await showConfirmDeleteDialog(
      context,
      title: 'Delete Column',
      message: columnDeleteMessage(column.name, cardCount),
    );

    if (confirmed && context.mounted) {
      await guardMutation(
        context,
        () => ref
            .read(columnListProvider(boardId).notifier)
            .deleteColumn(column.id),
        'Failed to delete column',
      );
    }
    // Always return false — let the Riverpod stream rebuild remove the
    // item, not the Dismissible animation. This avoids the common race
    // between Dismissible removal and reactive list rebuild.
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      itemCount: columns.length,
      onReorder: (oldIndex, newIndex) async {
        // Flutter's ReorderableListView provides pre-removal indices.
        // When moving downward, newIndex is one past the actual insertion
        // point because the removed item still occupies its original slot.
        // computeOrderKeyBetween expects post-removal indexing.
        final adjustedNew = oldIndex < newIndex ? newIndex - 1 : newIndex;
        await guardMutation(
          context,
          () => ref
              .read(columnListProvider(boardId).notifier)
              .reorderColumn(oldIndex, adjustedNew),
          'Failed to reorder column',
        );
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final elevation = Tween<double>(
              begin: 0,
              end: 4,
            ).evaluate(animation);
            return Material(
              elevation: elevation,
              borderRadius: BorderRadius.circular(8),
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final column = columns[index];
        return _ColumnRow(
          key: ValueKey(column.id),
          column: column,
          index: index,
          onRename: (newName) async {
            if (!context.mounted) return;
            await guardMutation(
              context,
              () => ref
                  .read(columnListProvider(boardId).notifier)
                  .renameColumn(column.id, newName),
              'Failed to rename column',
            );
          },
          onConfirmDismiss: () => _confirmDelete(context, ref, column),
        );
      },
    );
  }
}

class _ColumnRow extends StatefulWidget {
  const _ColumnRow({
    required super.key,
    required this.column,
    required this.index,
    required this.onRename,
    required this.onConfirmDismiss,
  });

  final KanbanColumn column;
  final int index;
  final Future<void> Function(String newName) onRename;
  final Future<bool> Function() onConfirmDismiss;

  @override
  State<_ColumnRow> createState() => _ColumnRowState();
}

class _ColumnRowState extends State<_ColumnRow> {
  final _focusNode = FocusNode();
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.column.name);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_ColumnRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update the controller text when the column name changes externally
    // (e.g., from the column header popup rename) but only if not editing.
    if (!_isEditing && oldWidget.column.name != widget.column.name) {
      _controller.text = widget.column.name;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onFocusChange() async {
    if (!_focusNode.hasFocus && _isEditing) {
      await _submitOrCancel();
    }
  }

  void _enterEditMode() {
    setState(() {
      _isEditing = true;
      _controller
        ..text = widget.column.name
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.column.name.length,
        );
    });
    _focusNode.requestFocus();
  }

  Future<void> _submitOrCancel() async {
    final newName = _controller.text.trim();
    if (newName.isNotEmpty && newName != widget.column.name) {
      await widget.onRename(newName);
    } else {
      _controller.text = widget.column.name;
    }
    if (mounted) setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(widget.column.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => widget.onConfirmDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: colorScheme.error,
        child: Icon(Icons.delete, color: colorScheme.onError),
      ),
      child: ListTile(
        leading: Tooltip(
          message: 'Reorder column',
          child: ReorderableDragStartListener(
            index: widget.index,
            child: const Icon(Icons.drag_handle),
          ),
        ),
        title: _isEditing
            ? KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.escape) {
                    _controller.text = widget.column.name;
                    setState(() => _isEditing = false);
                    _focusNode.unfocus();
                  }
                },
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLength: maxColumnNameLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  onSubmitted: (_) => _submitOrCancel(),
                ),
              )
            : GestureDetector(
                onTap: _enterEditMode,
                child: Text(widget.column.name),
              ),
      ),
    );
  }
}

class _AddColumnField extends ConsumerStatefulWidget {
  const _AddColumnField({required this.boardId, required this.atLimit});

  final String boardId;
  final bool atLimit;

  @override
  ConsumerState<_AddColumnField> createState() => _AddColumnFieldState();
}

class _AddColumnFieldState extends ConsumerState<_AddColumnField> {
  final _controller = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(_AddColumnField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.atLimit != widget.atLimit) _onChanged();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    final valid = _controller.text.trim().isNotEmpty && !widget.atLimit;
    if (valid != _isValid) {
      setState(() => _isValid = valid);
    }
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty || widget.atLimit) return;

    await guardMutation(
      context,
      () => ref
          .read(columnListProvider(widget.boardId).notifier)
          .createColumn(name),
      'Failed to create column',
    );
    // guardMutation swallows errors — always clear the field.
    // Worst case on limit error: user re-types (snackbar is visible).
    if (mounted) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            maxLength: maxColumnNameLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Column name',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            onSubmitted: _isValid ? (_) => _submit() : null,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _isValid ? _submit : null,
          icon: const Icon(Icons.add),
          tooltip: 'Add column',
        ),
      ],
    );
  }
}

class _SheetColumnSkeleton extends StatelessWidget {
  const _SheetColumnSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: ShimmerScope(
        child: Column(
          children: [
            _SkeletonColumnRow(),
            SizedBox(height: 8),
            _SkeletonColumnRow(),
            SizedBox(height: 8),
            _SkeletonColumnRow(),
          ],
        ),
      ),
    );
  }
}

class _SkeletonColumnRow extends StatelessWidget {
  const _SkeletonColumnRow();

  @override
  Widget build(BuildContext context) {
    // Uses real ListTile so height, leading gap, and padding match _ColumnRow.
    return const ListTile(
      leading: ShimmerBlock(width: 24, height: 24),
      title: ShimmerBlock(width: 140, height: 16),
    );
  }
}
