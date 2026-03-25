import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board/core/guard_mutation.dart';
import 'package:kanban_board/core/reorder_helpers.dart';
import 'package:kanban_board/features/board/domain/board_repository.dart';
import 'package:kanban_board/features/board/domain/kanban_card.dart';
import 'package:kanban_board/features/board/domain/kanban_column.dart';
import 'package:kanban_board/features/board/presentation/auto_scroll_handler.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:kanban_board/features/board/presentation/providers/card_providers.dart';
import 'package:kanban_board/features/board/presentation/providers/column_providers.dart';
import 'package:kanban_board/features/board/presentation/providers/drag_providers.dart';
import 'package:kanban_board/features/board/presentation/widgets/board_form_sheet.dart';
import 'package:kanban_board/features/board/presentation/widgets/card_form_sheet.dart';
import 'package:kanban_board/features/board/presentation/widgets/column_form_sheet.dart';
import 'package:kanban_board/features/board/presentation/widgets/column_management_sheet.dart';

part 'board_detail_screen.card.dart';
part 'board_detail_screen.column.dart';
part 'board_detail_screen.drag.dart';

const _kColumnWidth = 300.0;
const _kColumnMarginH = 6.0;

enum _BoardMenuAction { rename, manageColumns }

enum _ColumnMenuAction { rename, delete }

class BoardDetailScreen extends ConsumerStatefulWidget {
  const BoardDetailScreen({required this.boardId, super.key});

  final String boardId;

  @override
  ConsumerState<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends ConsumerState<BoardDetailScreen> {
  late final AppLifecycleListener _lifecycleListener;

  /// Cached at initState so _stampLastUsed can run in dispose
  /// without touching ref (which is invalid after deactivation).
  late final BoardRepository _repository;
  bool _hasStamped = false;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(boardRepositoryProvider);
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onLifecycleChange,
    );
  }

  @override
  void didUpdateWidget(BoardDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.boardId != widget.boardId) {
      _stampLastUsed();
      _hasStamped = false;
    }
  }

  @override
  void dispose() {
    _stampLastUsed();
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _onLifecycleChange(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _stampLastUsed();
    } else if (state == AppLifecycleState.resumed) {
      // User returned to the app — allow a fresh stamp on next
      // pause/dispose so lastUsedAt reflects the final exit, not
      // the first background event.
      _hasStamped = false;
    }
  }

  /// Stamps `lastUsedAt` on the board. Fire-and-forget — Hive's
  /// in-memory-first writes make the data immediately available.
  /// Guarded by [_hasStamped] to prevent double-writes when
  /// lifecycle callback and dispose race.
  void _stampLastUsed() {
    if (_hasStamped) return;
    _hasStamped = true;

    // Best-effort: repository may already be disposed during teardown.
    unawaited(
      _repository
          .getBoard(widget.boardId)
          .then((board) async {
            if (board != null) {
              await _repository.updateBoard(
                board.copyWith(lastUsedAt: DateTime.now()),
              );
            }
          })
          .catchError(
            // Swallow disposal-related Errors (StateError, HiveError);
            // let Exceptions propagate.
            (_) {},
            test: (e) => e is Error,
          ),
    );
  }

  Future<void> _renameBoard(String currentName) async {
    final newName = await BoardFormSheet.show(
      context,
      initialName: currentName,
    );
    if (newName != null && newName != currentName && mounted) {
      await guardMutation(
        context,
        () => ref
            .read(boardListProvider.notifier)
            .renameBoard(widget.boardId, newName),
        'Failed to rename board',
      );
    }
  }

  Future<void> _addCardToFirstColumn() async {
    final columns =
        ref.read(columnListProvider(widget.boardId)).value;
    if (columns == null || columns.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a column first')),
      );
      return;
    }
    final result = await CardFormSheet.show(context);
    if (result != null && mounted) {
      await guardMutation(
        context,
        () => ref
            .read(cardListProvider(columns.first.id).notifier)
            .createCard(
              title: result.title,
              description: result.description,
            ),
        'Failed to create card',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final boardAsync = ref.watch(boardProvider(widget.boardId));

    return boardAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $error')),
      ),
      data: (board) {
        if (board == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Board not found')),
          );
        }

        final columnsAsync = ref.watch(columnListProvider(widget.boardId));

        return Scaffold(
          appBar: AppBar(
            title: Text(board.name),
            actions: [
              PopupMenuButton<_BoardMenuAction>(
                onSelected: (action) async {
                  switch (action) {
                    case _BoardMenuAction.rename:
                      await _renameBoard(board.name);
                    case _BoardMenuAction.manageColumns:
                      if (!mounted) return;
                      await ColumnManagementSheet.show(
                        context,
                        boardId: widget.boardId,
                      );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _BoardMenuAction.rename,
                    child: Text('Rename'),
                  ),
                  PopupMenuItem(
                    value: _BoardMenuAction.manageColumns,
                    child: Text('Manage Columns'),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _addCardToFirstColumn,
            child: const Icon(Icons.note_add),
          ),
          body: columnsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => Center(
              child: Text('Error: $error'),
            ),
            data: (columns) {
              if (columns.isEmpty) {
                return const Center(
                  child: Text(
                    'No columns yet. Use the menu to add one.',
                  ),
                );
              }
              return _BoardScrollView(
                boardId: widget.boardId,
                columns: columns,
              );
            },
          ),
        );
      },
    );
  }
}
