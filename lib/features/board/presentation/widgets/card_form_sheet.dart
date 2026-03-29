import 'package:flutter/material.dart';
import 'package:kanban_board/core/sheet_body.dart';
import 'package:kanban_board/core/string_utils.dart';
import 'package:kanban_board/features/board/domain/kanban_card.dart';

const _maxTitleLength = 100;
const _maxDescriptionLength = 500;

// ── Result types ────────────────────────────────────────────────────

sealed class CardDetailResult {
  const CardDetailResult();
}

class CardEdited extends CardDetailResult {
  const CardEdited({required this.title, required this.description});
  final String title;
  final String description;
}

class CardDeleted extends CardDetailResult {
  const CardDeleted();
}

// ── Create-only form (used by "Add Card" button) ────────────────────

class CardFormSheet extends StatefulWidget {
  const CardFormSheet({super.key});

  @override
  State<CardFormSheet> createState() => _CardFormSheetState();

  static Future<({String title, String description})?> show(
    BuildContext context,
  ) {
    return showAppBottomSheet<({String title, String description})>(
      context,
      child: const CardFormSheet(),
    );
  }
}

class _CardFormSheetState extends State<CardFormSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onChanged() {
    final valid = _titleController.text.trim().isNotEmpty;
    if (valid != _isValid) {
      setState(() => _isValid = valid);
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) {
      Navigator.of(context).pop(
        (
          title: title,
          description: _descriptionController.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      children: [
        Text(
          'New Card',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          autofocus: true,
          maxLength: _maxTitleLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
          onSubmitted: _isValid ? (_) => _submit() : null,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          maxLength: _maxDescriptionLength,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _isValid ? _submit : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

// ── Detail sheet for existing cards (view → edit / delete) ──────────

class CardDetailSheet extends StatefulWidget {
  const CardDetailSheet({required this.card, super.key});

  final KanbanCard card;

  @override
  State<CardDetailSheet> createState() => _CardDetailSheetState();

  static Future<CardDetailResult?> show(
    BuildContext context, {
    required KanbanCard card,
  }) {
    return showAppBottomSheet<CardDetailResult>(
      context,
      child: CardDetailSheet(card: card),
    );
  }
}

class _CardDetailSheetState extends State<CardDetailSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  bool _editing = false;
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.card.title);
    _descriptionController = TextEditingController(
      text: widget.card.description,
    );
    _titleController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onChanged() {
    final valid = _titleController.text.trim().isNotEmpty;
    if (valid != _isValid) {
      setState(() => _isValid = valid);
    }
  }

  void _submitEdit() {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) {
      Navigator.of(context).pop(
        CardEdited(
          title: title,
          description: _descriptionController.text.trim(),
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text("Delete '${truncateForDisplay(widget.card.title)}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop(const CardDeleted());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      children: [
        if (_editing)
          _CardEditView(
            titleController: _titleController,
            descriptionController: _descriptionController,
            isValid: _isValid,
            onSubmit: _submitEdit,
          )
        else
          _CardDetailView(
            card: widget.card,
            onEdit: () => setState(() => _editing = true),
            onDelete: _confirmDelete,
          ),
      ],
    );
  }
}

class _CardDetailView extends StatelessWidget {
  const _CardDetailView({
    required this.card,
    required this.onEdit,
    required this.onDelete,
  });

  final KanbanCard card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                card.title,
                style: theme.textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete),
              tooltip: 'Delete',
              style: IconButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ],
        ),
        if (card.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            card.description,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ],
    );
  }
}

class _CardEditView extends StatelessWidget {
  const _CardEditView({
    required this.titleController,
    required this.descriptionController,
    required this.isValid,
    required this.onSubmit,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final bool isValid;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Edit Card',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: titleController,
          autofocus: true,
          maxLength: _maxTitleLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
          onSubmitted: isValid ? (_) => onSubmit() : null,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descriptionController,
          maxLength: _maxDescriptionLength,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: isValid ? onSubmit : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
