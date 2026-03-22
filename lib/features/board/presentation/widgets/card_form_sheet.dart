import 'dart:math' as math;

import 'package:flutter/material.dart';
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
    return showModalBottomSheet<({String title, String description})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CardFormSheet(),
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
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final padding = MediaQuery.paddingOf(context);
    final bottomInset = math.max(viewInsets.bottom, padding.bottom);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: bottomInset + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
      ),
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
    return showModalBottomSheet<CardDetailResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CardDetailSheet(card: card),
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
    _descriptionController =
        TextEditingController(text: widget.card.description);
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
        content: Text("Delete '${widget.card.title}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop(const CardDeleted());
    }
  }

  Widget _buildDetailView(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.card.title,
                style: theme.textTheme.titleLarge,
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
            ),
            IconButton(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete),
              tooltip: 'Delete',
            ),
          ],
        ),
        if (widget.card.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            widget.card.description,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ],
    );
  }

  Widget _buildEditView(BuildContext context) {
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
          controller: _titleController,
          autofocus: true,
          maxLength: _maxTitleLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
          onSubmitted: _isValid ? (_) => _submitEdit() : null,
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
          onPressed: _isValid ? _submitEdit : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final padding = MediaQuery.paddingOf(context);
    final bottomInset = math.max(viewInsets.bottom, padding.bottom);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: bottomInset + 24,
      ),
      child: _editing ? _buildEditView(context) : _buildDetailView(context),
    );
  }
}
