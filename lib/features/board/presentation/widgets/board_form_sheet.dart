import 'dart:math' as math;

import 'package:flutter/material.dart';

const _maxBoardNameLength = 50;

/// Reusable bottom sheet for creating or renaming a board.
///
/// Returns the entered name via [Navigator.pop] on submit, or `null`
/// if dismissed.
class BoardFormSheet extends StatefulWidget {
  const BoardFormSheet({
    super.key,
    this.initialName,
  });

  /// Pre-fill for rename mode. Null = create mode.
  final String? initialName;

  @override
  State<BoardFormSheet> createState() => _BoardFormSheetState();

  /// Show the bottom sheet and return the entered name, or null if dismissed.
  static Future<String?> show(
    BuildContext context, {
    String? initialName,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BoardFormSheet(initialName: initialName),
    );
  }
}

class _BoardFormSheetState extends State<BoardFormSheet> {
  late final TextEditingController _controller;
  bool _isValid = false;

  bool get _isRename => widget.initialName != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
    _isValid = _controller.text.trim().isNotEmpty;
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    final valid = _controller.text.trim().isNotEmpty;
    if (valid != _isValid) {
      setState(() => _isValid = valid);
    }
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      Navigator.of(context).pop(name);
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
            _isRename ? 'Rename Board' : 'New Board',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: _maxBoardNameLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Board name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: _isValid ? (_) => _submit() : null,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isValid ? _submit : null,
            child: Text(_isRename ? 'Rename' : 'Create'),
          ),
        ],
      ),
    );
  }
}
