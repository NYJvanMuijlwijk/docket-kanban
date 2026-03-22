import 'package:flutter/material.dart';

const _maxTitleLength = 100;
const _maxDescriptionLength = 500;

class CardFormSheet extends StatefulWidget {
  const CardFormSheet({
    super.key,
    this.initialTitle,
    this.initialDescription,
  });

  final String? initialTitle;
  final String? initialDescription;

  @override
  State<CardFormSheet> createState() => _CardFormSheetState();

  static Future<({String title, String description})?> show(
    BuildContext context, {
    String? initialTitle,
    String? initialDescription,
  }) {
    return showModalBottomSheet<({String title, String description})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CardFormSheet(
        initialTitle: initialTitle,
        initialDescription: initialDescription,
      ),
    );
  }
}

class _CardFormSheetState extends State<CardFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  bool _isValid = false;

  bool get _isEdit => widget.initialTitle != null;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.initialTitle ?? '');
    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
    _isValid = _titleController.text.trim().isNotEmpty;
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
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEdit ? 'Edit Card' : 'New Card',
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
            child: Text(_isEdit ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }
}
